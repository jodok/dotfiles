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
  */claude/gitconfig) source_file="$DOTFILES_TEST_ROOT/claude/gitconfig" ;;
  */claude/ssh_config) source_file="$DOTFILES_TEST_ROOT/claude/ssh_config" ;;
  */claude/bin/claude-ssh-agent) source_file="$DOTFILES_TEST_ROOT/claude/bin/claude-ssh-agent" ;;
  */claude/bin/claude-ssh-sign) source_file="$DOTFILES_TEST_ROOT/claude/bin/claude-ssh-sign" ;;
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
export ZSH="$HOME/omz-alt"
export ZSH_CUSTOM="$HOME/custom-alt"

mkdir -p "$ZSH" "$ZSH_CUSTOM"
printf 'local aliases\n' > "$ZSH_CUSTOM/aliases.zsh"
cat > "$HOME/.zshrc" <<'EOF'
if [[ -n "$HOST" ]]; then
  source "$HOME/.zshrc.local"
fi
source $ZSH/oh-my-zsh.sh
EOF

"$ROOT_DIR/install.sh" >/dev/null
printf 'second local aliases\n' > "$ZSH_CUSTOM/aliases.zsh"
"$ROOT_DIR/install.sh" >/dev/null
"$ROOT_DIR/install.sh" >/dev/null

test "$(sed -n '1p' "$ZSH_CUSTOM/aliases.zsh.bak")" = 'local aliases'
test "$(sed -n '1p' "$ZSH_CUSTOM/aliases.zsh.bak.1")" = 'second local aliases'
cmp "$ZSH_CUSTOM/aliases.zsh" "$ROOT_DIR/zsh/aliases.zsh"
test -f "$ZSH_CUSTOM/update-check.zsh"
test -L "$HOME/.codex/AGENTS.md"
test -f "$HOME/.oh-my-jodok.zsh"
grep -Fqx "export ZSH=$ZSH" "$HOME/.zshrc"

grep -Fq 'if [[ -n "$HOST" ]]; then' "$HOME/.zshrc"
test "$(grep -Fc 'source "$HOME/.zshrc.local"' "$HOME/.zshrc")" = 1
test "$(grep -Fc 'source $ZSH/oh-my-zsh.sh' "$HOME/.zshrc")" = 1

# The identity files install regardless of 1Password, and the key step is skipped
# cleanly when `op` cannot answer — an install must not fail because a vault is
# locked. A stub `op` shadows any real one, so the test never touches a live vault.
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test -f "$HOME/.claude/gitconfig"
test -f "$HOME/.claude/ssh_config"
test -x "$HOME/.claude/bin/claude-ssh-agent"
test -x "$HOME/.claude/bin/claude-ssh-sign"
test ! -e "$HOME/.claude/claude-signing.pub"

# With `op` answering, the public key lands and allowed_signers gains the line --
# appended, because that file is the user's and usually carries their own keys.
mkdir -p "$HOME/.config/git"
printf 'jodok@batlogg.com ssh-ed25519 AAAAPERSONAL\n' > "$HOME/.config/git/allowed_signers"
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read) printf 'ssh-ed25519 AAAATESTKEY comment' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'AAAATESTKEY' "$HOME/.claude/claude-signing.pub"
grep -Fq 'AAAAPERSONAL' "$HOME/.config/git/allowed_signers"
grep -Fq 'jodok@batlogg.com ssh-ed25519 AAAATESTKEY' "$HOME/.config/git/allowed_signers"

# Re-running adds nothing: the line is matched, not blindly appended.
"$ROOT_DIR/install.sh" >/dev/null
test "$(grep -Fc 'AAAATESTKEY' "$HOME/.config/git/allowed_signers")" = 1

printf 'install tests passed\n'
