#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home" "$TEST_DIR/state"

cat > "$TEST_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=''
url=''
connect_timeout=''
max_time=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -H)
      shift 2
      ;;
    --connect-timeout)
      connect_timeout="$2"
      shift 2
      ;;
    --max-time)
      max_time="$2"
      shift 2
      ;;
    -*) shift ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

test -n "$connect_timeout"
test -n "$max_time"

case "$url" in
  https://api.github.com/*)
    if [ "${FAKE_API_FAIL:-0}" = 1 ]; then
      exit 22
    fi
    printf '{"sha":"%s"}\n' "$FAKE_REMOTE_SHA"
    ;;
  https://raw.githubusercontent.com/*/install.sh)
    cp "$FAKE_INSTALLER" "$output"
    ;;
  *)
    echo "unexpected URL: $url" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$TEST_DIR/bin/curl"

cat > "$TEST_DIR/installer.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${FAKE_INSTALL_FAIL:-0}" = 1 ]; then
  exit 1
fi

printf 'install\n' >> "$FAKE_INSTALL_LOG"
if [ -n "${FAKE_INSTALL_DELAY:-}" ]; then
  sleep "$FAKE_INSTALL_DELAY"
fi

count=0
if [ -f "$FAKE_INSTALL_COUNT" ]; then
  count="$(sed -n '1p' "$FAKE_INSTALL_COUNT")"
fi
printf '%s\n' "$((count + 1))" > "$FAKE_INSTALL_COUNT"
EOF

export HOME="$TEST_DIR/home"
export PATH="$TEST_DIR/bin:$PATH"
export FAKE_INSTALLER="$TEST_DIR/installer.sh"
export FAKE_INSTALL_COUNT="$TEST_DIR/install-count"
export FAKE_INSTALL_LOG="$TEST_DIR/install.log"
export FAKE_REMOTE_SHA=1111111111111111111111111111111111111111
export OH_MY_JODOK_STATE_DIR="$TEST_DIR/state"
export OH_MY_JODOK_UPDATE_DAYS=13

export FAKE_API_FAIL=1
if "$ROOT_DIR/update.sh" --record-current >/dev/null 2>&1; then
  echo "failed API lookup unexpectedly recorded a revision" >&2
  exit 1
fi
test ! -e "$TEST_DIR/state/last-applied"
unset FAKE_API_FAIL

"$ROOT_DIR/update.sh" --auto
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 1
test "$(sed -n '1p' "$TEST_DIR/state/last-applied")" = "$FAKE_REMOTE_SHA"

"$ROOT_DIR/update.sh" --auto
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 1

printf '0\n' > "$TEST_DIR/state/last-check"
"$ROOT_DIR/update.sh" --auto
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 1

export FAKE_REMOTE_SHA=2222222222222222222222222222222222222222
printf '0\n' > "$TEST_DIR/state/last-check"
"$ROOT_DIR/update.sh" --auto
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 2
test "$(sed -n '1p' "$TEST_DIR/state/last-applied")" = "$FAKE_REMOTE_SHA"

export FAKE_REMOTE_SHA=3333333333333333333333333333333333333333
export FAKE_INSTALL_FAIL=1
printf '0\n' > "$TEST_DIR/state/last-check"
if "$ROOT_DIR/update.sh" --auto >/dev/null 2>&1; then
  echo "failed automatic install unexpectedly succeeded" >&2
  exit 1
fi
test "$(sed -n '1p' "$TEST_DIR/state/last-check")" = 0
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 2

unset FAKE_INSTALL_FAIL
"$ROOT_DIR/update.sh" --auto
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 3
test "$(sed -n '1p' "$TEST_DIR/state/last-applied")" = "$FAKE_REMOTE_SHA"

"$ROOT_DIR/update.sh"
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 4

export FAKE_REMOTE_SHA=4444444444444444444444444444444444444444
export FAKE_INSTALL_DELAY=1
printf '0\n' > "$TEST_DIR/state/last-check"
"$ROOT_DIR/update.sh" --auto &
first_pid=$!
"$ROOT_DIR/update.sh" --auto &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
unset FAKE_INSTALL_DELAY
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 5
test "$(wc -l < "$FAKE_INSTALL_LOG" | tr -d ' ')" = 5

if "$ROOT_DIR/update.sh" --unknown >/dev/null 2>&1; then
  echo "unknown option unexpectedly succeeded" >&2
  exit 1
fi

printf 'update tests passed\n'
