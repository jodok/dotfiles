#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-jodok/dotfiles}"
BRANCH="${BRANCH:-main}"
CURL_CONNECT_TIMEOUT="${OH_MY_JODOK_CURL_CONNECT_TIMEOUT:-3}"
CURL_MAX_TIME="${OH_MY_JODOK_CURL_MAX_TIME:-15}"
STATE_DIR="${OH_MY_JODOK_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-jodok}"
UPDATE_DAYS="${OH_MY_JODOK_UPDATE_DAYS:-13}"
LAST_CHECK_FILE="$STATE_DIR/last-check"
LAST_APPLIED_FILE="$STATE_DIR/last-applied"
API_URL="https://api.github.com/repos/${REPO_SLUG}/commits/${BRANCH}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}"

log() {
  printf '\n[%s] %s\n' "oh-my-jodok" "$*"
}

write_state() {
  local target="$1"
  local value="$2"
  local tmp

  mkdir -p "$STATE_DIR"
  tmp="$(mktemp "$STATE_DIR/.state.XXXXXX")"
  printf '%s\n' "$value" > "$tmp"
  mv "$tmp" "$target"
}

read_state() {
  local target="$1"
  if [ -f "$target" ]; then
    sed -n '1p' "$target"
  fi
}

fetch_remote_sha() {
  curl -fsSL --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    -H 'Accept: application/vnd.github+json' \
    "$API_URL" 2>/dev/null \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["sha"])' 2>/dev/null
}

record_version() {
  local commit="$1"
  local now

  now="$(date +%s)"
  write_state "$LAST_APPLIED_FILE" "$commit"
  write_state "$LAST_CHECK_FILE" "$now"
}

record_current_version() {
  local remote_sha

  remote_sha="$(fetch_remote_sha)" || return
  if [ -z "$remote_sha" ]; then
    return 1
  fi
  record_version "$remote_sha"
}

apply_update() {
  local ref="$1"
  local commit="${2:-}"
  local installer

  installer="$(mktemp)"
  if ! curl -fsSL --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" "$RAW_BASE/$ref/install.sh" -o "$installer"; then
    rm -f "$installer"
    return 1
  fi

  if ! OH_MY_JODOK_INSTALL_COMMIT="$commit" \
    OH_MY_JODOK_CURL_CONNECT_TIMEOUT="$CURL_CONNECT_TIMEOUT" \
    OH_MY_JODOK_CURL_MAX_TIME="$CURL_MAX_TIME" \
    REPO_SLUG="$REPO_SLUG" BRANCH="$ref" bash "$installer"; then
    rm -f "$installer"
    return 1
  fi
  rm -f "$installer"

  if [ -n "$commit" ]; then
    record_version "$commit"
  fi
}

is_check_due() {
  local last_check
  local now
  local interval

  case "$UPDATE_DAYS" in
    ''|*[!0-9]*)
      echo "OH_MY_JODOK_UPDATE_DAYS must be a non-negative integer" >&2
      return 2
      ;;
  esac

  last_check="$(read_state "$LAST_CHECK_FILE")"
  case "$last_check" in
    ''|*[!0-9]*) return 0 ;;
  esac

  now="$(date +%s)"
  interval=$((UPDATE_DAYS * 86400))
  [ $((now - last_check)) -ge "$interval" ]
}

auto_update() {
  local due_status
  local remote_sha
  local installed_sha

  if is_check_due; then
    due_status=0
  else
    due_status=$?
  fi
  if [ "$due_status" -eq 1 ]; then
    return 0
  fi
  if [ "$due_status" -ne 0 ]; then
    return "$due_status"
  fi

  if ! remote_sha="$(fetch_remote_sha)"; then
    write_state "$LAST_CHECK_FILE" "$(date +%s)"
    return 0
  fi

  installed_sha="$(read_state "$LAST_APPLIED_FILE")"
  if [ "$remote_sha" = "$installed_sha" ]; then
    write_state "$LAST_CHECK_FILE" "$(date +%s)"
    return 0
  fi

  log "applying dotfiles update ${remote_sha:0:8}"
  apply_update "$remote_sha" "$remote_sha"
}

manual_update() {
  local remote_sha

  if remote_sha="$(fetch_remote_sha)"; then
    log "installing latest dotfiles (${remote_sha:0:8})"
    apply_update "$remote_sha" "$remote_sha"
    return
  fi

  log "could not resolve the latest commit; installing from $BRANCH"
  apply_update "$BRANCH"
}

usage() {
  cat <<'EOF'
Usage: update.sh [--auto | --record COMMIT | --record-current]

With no argument, installs the latest dotfiles immediately.
EOF
}

case "${1:-}" in
  '') manual_update ;;
  --auto) auto_update ;;
  --record)
    if [ "$#" -ne 2 ] || [ -z "$2" ]; then
      usage >&2
      exit 2
    fi
    record_version "$2"
    ;;
  --record-current)
    record_current_version
    ;;
  -h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
