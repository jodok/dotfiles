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
cat > "$HOME/.zshrc" <<'EOF'
if [[ -n "$HOST" ]]; then
  source "$HOME/.zshrc.local"
fi
source $ZSH/oh-my-zsh.sh
EOF

"$ROOT_DIR/install.sh" >/dev/null
printf 'second local aliases\n' > "$HOME/.oh-my-zsh/custom/aliases.zsh"
"$ROOT_DIR/install.sh" >/dev/null
"$ROOT_DIR/install.sh" >/dev/null

test "$(sed -n '1p' "$HOME/.oh-my-zsh/custom/aliases.zsh.bak")" = 'local aliases'
test "$(sed -n '1p' "$HOME/.oh-my-zsh/custom/aliases.zsh.bak.1")" = 'second local aliases'
cmp "$HOME/.oh-my-zsh/custom/aliases.zsh" "$ROOT_DIR/zsh/aliases.zsh"
test -f "$HOME/.oh-my-zsh/custom/update-check.zsh"
test -L "$HOME/.codex/AGENTS.md"
test -f "$HOME/.oh-my-jodok.zsh"

grep -Fq 'if [[ -n "$HOST" ]]; then' "$HOME/.zshrc"
test "$(grep -Fc 'source "$HOME/.zshrc.local"' "$HOME/.zshrc")" = 1
test "$(grep -Fc 'source $ZSH/oh-my-zsh.sh' "$HOME/.zshrc")" = 1

printf 'install tests passed\n'
