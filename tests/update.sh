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
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -H|--connect-timeout|--max-time)
      shift 2
      ;;
    -*) shift ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

case "$url" in
  https://api.github.com/*)
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
export FAKE_REMOTE_SHA=1111111111111111111111111111111111111111
export OH_MY_JODOK_STATE_DIR="$TEST_DIR/state"
export OH_MY_JODOK_UPDATE_DAYS=13

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

"$ROOT_DIR/update.sh"
test "$(sed -n '1p' "$FAKE_INSTALL_COUNT")" = 3

if "$ROOT_DIR/update.sh" --unknown >/dev/null 2>&1; then
  echo "unknown option unexpectedly succeeded" >&2
  exit 1
fi

printf 'update tests passed\n'
