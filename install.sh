#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-jodok/dotfiles}"
BRANCH="${BRANCH:-main}"
CURL_CONNECT_TIMEOUT="${OH_MY_JODOK_CURL_CONNECT_TIMEOUT:-3}"
CURL_MAX_TIME="${OH_MY_JODOK_CURL_MAX_TIME:-15}"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
THEMES_DIR="$CUSTOM_DIR/themes"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}"
THEME_URL="$RAW_BASE/oh-my-zsh/themes/jodok.zsh-theme"
EXPORTS_URL="$RAW_BASE/zsh/exports.zsh"
ALIASES_URL="$RAW_BASE/zsh/aliases.zsh"
UPDATE_URL="$RAW_BASE/update.sh"
UPDATE_CHECK_URL="$RAW_BASE/zsh/update-check.zsh"
AGENT_RULES_URL="$RAW_BASE/agents/global-rules.md"
CLAUDE_MD_URL="$RAW_BASE/agents/claude.md"

log() {
  printf '\n[%s] %s\n' "dotfiles" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is required but not installed" >&2
    exit 1
  }
}

ensure_oh_my_zsh() {
  if [ -d "$ZSH_DIR" ]; then
    log "oh-my-zsh already installed"
    return
  fi

  require_cmd git
  require_cmd curl

  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL --connect-timeout "$CURL_CONNECT_TIMEOUT" \
      --max-time "$CURL_MAX_TIME" \
      https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

upsert_line() {
  local file="$1"
  local key="$2"
  local line="$3"

  python3 - "$file" "$key" "$line" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
line = sys.argv[3]
text = path.read_text() if path.exists() else ""
lines = text.splitlines()
replaced = False
out = []
for existing in lines:
    if existing.strip().startswith(key):
        if not replaced:
            out.append(line)
            replaced = True
        continue
    out.append(existing)
if not replaced:
    if out and out[-1] != "":
        out.append("")
    out.append(line)
path.write_text("\n".join(out).rstrip() + "\n")
PY
}

remove_exact_line() {
  local file="$1"
  local line="$2"

  python3 - "$file" "$line" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
line = sys.argv[2]
text = path.read_text() if path.exists() else ""
lines = text.splitlines()
path.write_text("\n".join(existing for existing in lines if existing != line).rstrip() + "\n")
PY
}

ensure_omz_source_order() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
lines = text.splitlines()
source_lines = [
    'source $ZSH/oh-my-zsh.sh',
    'source "$ZSH/oh-my-zsh.sh"',
    '[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"',
]
if any(line.strip() in source_lines for line in lines):
    path.write_text("\n".join(lines).rstrip() + "\n")
    sys.exit(0)
if lines and lines[-1] != "":
    lines.append("")
lines.append('source $ZSH/oh-my-zsh.sh')
path.write_text("\n".join(lines).rstrip() + "\n")
PY
}

patch_zshrc() {
  local zshrc="$HOME/.zshrc"
  local quoted_zsh_dir
  touch "$zshrc"

  if [ "$ZSH_DIR" = "$HOME/.oh-my-zsh" ]; then
    quoted_zsh_dir='"$HOME/.oh-my-zsh"'
  else
    printf -v quoted_zsh_dir '%q' "$ZSH_DIR"
  fi
  upsert_line "$zshrc" 'export ZSH=' "export ZSH=$quoted_zsh_dir"
  upsert_line "$zshrc" 'ZSH_THEME=' 'ZSH_THEME="jodok"'
  upsert_line "$zshrc" "zstyle ':omz:update' mode" "zstyle ':omz:update' mode auto"
  upsert_line "$zshrc" 'COMPLETION_WAITING_DOTS=' 'COMPLETION_WAITING_DOTS="true"'
  ensure_omz_source_order "$zshrc"
  remove_exact_line "$zshrc" 'PROMPT="%{$fg[red]%}%m %{$reset_color%}${PROMPT}"'

  log "patched $zshrc"
}

install_managed_file() {
  local url="$1"
  local target="$2"
  local tmp

  tmp="$(mktemp)"
  curl -fsSL --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" "$url" -o "$tmp"
  if [ -f "$target" ] && ! cmp -s "$tmp" "$target"; then
    backup_file "$target"
  fi
  mkdir -p "$(dirname "$target")"
  mv "$tmp" "$target"
  chmod 644 "$target"
  log "installed $target"
}

backup_file() {
  local target="$1"
  local backup="$target.bak"
  local suffix=1

  while [ -e "$backup" ]; do
    backup="$target.bak.$suffix"
    suffix=$((suffix + 1))
  done

  cp "$target" "$backup"
  log "backed up $target to $backup"
}

install_agent_rules() {
  local rules_target="$HOME/.agents/global-rules.md"
  local codex_agents="$HOME/.codex/AGENTS.md"

  install_managed_file "$AGENT_RULES_URL" "$rules_target"
  install_managed_file "$CLAUDE_MD_URL" "$HOME/.claude/CLAUDE.md"

  mkdir -p "$HOME/.codex"
  if [ -e "$codex_agents" ] && [ ! -L "$codex_agents" ] && [ -s "$codex_agents" ]; then
    backup_file "$codex_agents"
  fi
  ln -sfn "$rules_target" "$codex_agents"
  log "linked $codex_agents -> $rules_target"
}

main() {
  require_cmd zsh
  require_cmd curl
  require_cmd python3

  ensure_oh_my_zsh

  mkdir -p "$THEMES_DIR" "$CUSTOM_DIR"

  install_managed_file "$THEME_URL" "$THEMES_DIR/jodok.zsh-theme"
  install_managed_file "$EXPORTS_URL" "$CUSTOM_DIR/exports.zsh"
  install_managed_file "$ALIASES_URL" "$CUSTOM_DIR/aliases.zsh"
  install_managed_file "$UPDATE_URL" "$CUSTOM_DIR/update.sh"
  install_managed_file "$UPDATE_CHECK_URL" "$CUSTOM_DIR/update-check.zsh"
  chmod +x "$CUSTOM_DIR/update.sh"

  install_agent_rules

  touch "$HOME/.zshrc.local" "$HOME/.zshenv.local" "$HOME/.oh-my-jodok.zsh"
  patch_zshrc

  if [ -n "${OH_MY_JODOK_INSTALL_COMMIT:-}" ]; then
    "$CUSTOM_DIR/update.sh" --record "$OH_MY_JODOK_INSTALL_COMMIT"
  elif ! "$CUSTOM_DIR/update.sh" --record-current; then
    log "could not record the installed revision; the next shell will retry"
  fi

  log "done"
  log "restart your shell or run: source ~/.zshrc"
}

main "$@"
