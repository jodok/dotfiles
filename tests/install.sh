#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home/.oh-my-zsh/custom"

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

if [[ "$url" == https://api.github.com/* ]]; then
  printf '{"sha":"4444444444444444444444444444444444444444"}\n'
  exit
fi

case "$url" in
  */oh-my-zsh/themes/jodok.zsh-theme)
    source_file="$DOTFILES_TEST_ROOT/oh-my-zsh/themes/jodok.zsh-theme"
    ;;
  */zsh/exports.zsh) source_file="$DOTFILES_TEST_ROOT/zsh/exports.zsh" ;;
  */zsh/aliases.zsh) source_file="$DOTFILES_TEST_ROOT/zsh/aliases.zsh" ;;
  */zsh/update-check.zsh) source_file="$DOTFILES_TEST_ROOT/zsh/update-check.zsh" ;;
  */update.sh) source_file="$DOTFILES_TEST_ROOT/update.sh" ;;
  */agents/global-rules.md) source_file="$DOTFILES_TEST_ROOT/agents/global-rules.md" ;;
  */agents/claude.md) source_file="$DOTFILES_TEST_ROOT/agents/claude.md" ;;
  *)
    echo "unexpected URL: $url" >&2
    exit 1
    ;;
esac

cp "$source_file" "$output"
EOF
chmod +x "$TEST_DIR/bin/curl"

export DOTFILES_TEST_ROOT="$ROOT_DIR"
export HOME="$TEST_DIR/home"
export PATH="$TEST_DIR/bin:$PATH"
unset ZSH ZSH_CUSTOM

printf 'local aliases\n' > "$HOME/.oh-my-zsh/custom/aliases.zsh"
printf 'source $ZSH/oh-my-zsh.sh\n' > "$HOME/.zshrc"

"$ROOT_DIR/install.sh" >/dev/null
"$ROOT_DIR/install.sh" >/dev/null

test "$(sed -n '1p' "$HOME/.oh-my-zsh/custom/aliases.zsh.bak")" = 'local aliases'
cmp "$HOME/.oh-my-zsh/custom/aliases.zsh" "$ROOT_DIR/zsh/aliases.zsh"
test -f "$HOME/.oh-my-zsh/custom/update-check.zsh"
test -L "$HOME/.codex/AGENTS.md"

local_line="$(grep -nF '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"' "$HOME/.zshrc" | cut -d: -f1)"
omz_line="$(grep -nF 'source $ZSH/oh-my-zsh.sh' "$HOME/.zshrc" | cut -d: -f1)"
test "$(grep -Fc '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"' "$HOME/.zshrc")" = 1
test "$local_line" -lt "$omz_line"

printf 'install tests passed\n'
