#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/custom"
cat > "$TEST_DIR/custom/update.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s|%s|%s|%s|%s\n' \
  "${OH_MY_JODOK_UPDATE_DAYS:-manual}" "$*" "${ZSH:-}" "${ZSH_CUSTOM:-}" "$0" >> "$UPDATE_CHECK_LOG"
EOF
chmod +x "$TEST_DIR/custom/update.sh"

export HOME="$TEST_DIR/home"
export ZDOTDIR="$HOME"
export ZSH_CUSTOM="$TEST_DIR/custom"
export UPDATE_CHECK_LOG="$TEST_DIR/update-check.log"
unset ZSH
mkdir -p "$HOME"

printf "zstyle ':omj:update' frequency 7\n" > "$HOME/.oh-my-jodok.zsh"
zsh -ic "source '$ROOT_DIR/zsh/update-check.zsh'"
test "$(sed -n '1p' "$UPDATE_CHECK_LOG")" = \
  "7|--auto|$HOME/.oh-my-zsh|$ZSH_CUSTOM|$ZSH_CUSTOM/update.sh"

env -u ZSH -u ZSH_CUSTOM zsh -ic \
  "ZSH='$TEST_DIR/omz-alt'; ZSH_CUSTOM='$TEST_DIR/custom'; source '$ROOT_DIR/zsh/aliases.zsh'; eval oh-my-jodok"
test "$(sed -n '2p' "$UPDATE_CHECK_LOG")" = \
  "manual||$TEST_DIR/omz-alt|$ZSH_CUSTOM|$ZSH_CUSTOM/update.sh"

printf "zstyle ':omj:update' mode disabled\n" > "$HOME/.oh-my-jodok.zsh"
zsh -ic "source '$ROOT_DIR/zsh/update-check.zsh'"
test "$(wc -l < "$UPDATE_CHECK_LOG" | tr -d ' ')" = 2

printf 'update-check tests passed\n'
