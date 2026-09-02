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
  read)
    case "$2" in
      *claude-auth*) printf 'ssh-ed25519 AAAAAUTHKEY comment' ;;
      *) printf 'ssh-ed25519 AAAATESTKEY comment' ;;
    esac
    ;;
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

# The identity has to be the default, not something to remember per command -- and
# settings.json is the user's own file, so the merge must preserve what is there.
printf '{"theme":"auto","env":{"EXISTING":"kept"},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo theirs"}]}]}}\n' \
  > "$HOME/.claude/settings.json"
"$ROOT_DIR/install.sh" >/dev/null
test "$(jq -r '.theme' "$HOME/.claude/settings.json")" = 'auto'
test "$(jq -r '.env.EXISTING' "$HOME/.claude/settings.json")" = 'kept'
test "$(jq -r '.env.GIT_CONFIG_GLOBAL' "$HOME/.claude/settings.json")" = "$HOME/.claude/gitconfig"
test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("echo theirs"))) | length' "$HOME/.claude/settings.json")" = 1
test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("claude-ssh-agent"))) | length' "$HOME/.claude/settings.json")" = 1

# Re-running adds no second copy of our hook.
"$ROOT_DIR/install.sh" >/dev/null
test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("claude-ssh-agent"))) | length' "$HOME/.claude/settings.json")" = 1

# A settings file that is not valid JSON is left alone rather than overwritten.
printf 'not json at all\n' > "$HOME/.claude/settings.json"
"$ROOT_DIR/install.sh" >/dev/null
test "$(cat "$HOME/.claude/settings.json")" = 'not json at all'

# Activating the git config while no signing key exists would leave a git that cannot
# commit at all -- the config it selects sets commit.gpgsign. A skipped 1Password step
# must stay a skipped step, not a broken workflow.
rm -f "$HOME/.claude/claude-signing.pub" "$HOME/.claude/settings.json"
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test ! -e "$HOME/.claude/claude-signing.pub"
test ! -e "$HOME/.claude/settings.json"

# With the key present, the settings are merged as before.
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) printf 'ssh-ed25519 AAAAAUTHKEY comment' ;;
      *) printf 'ssh-ed25519 AAAATESTKEY comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test "$(jq -r '.env.GIT_CONFIG_GLOBAL' "$HOME/.claude/settings.json")" = "$HOME/.claude/gitconfig"
grep -Fq 'AAAAAUTHKEY' "$HOME/.claude/claude-auth.pub"

# The python fallback must refuse a settings file it cannot parse, exactly as the jq
# path does. Only the jq path was covered before, which is how a reset slipped through.
printf 'not json at all\n' > "$HOME/.claude/settings.json"
CLAUDE_JSON_TOOL=python3 "$ROOT_DIR/install.sh" >/dev/null
test "$(cat "$HOME/.claude/settings.json")" = 'not json at all'

# And through python it must still merge correctly, preserving what was there.
printf '{"theme":"auto","env":{"EXISTING":"kept"}}\n' > "$HOME/.claude/settings.json"
CLAUDE_JSON_TOOL=python3 "$ROOT_DIR/install.sh" >/dev/null
test "$(jq -r '.env.EXISTING' "$HOME/.claude/settings.json")" = 'kept'
test "$(jq -r '.theme' "$HOME/.claude/settings.json")" = 'auto'
grep -Fq 'claude-ssh-agent' "$HOME/.claude/settings.json"

# Half an identity is not an identity: the loader and the ssh config both need the
# auth key, so activating on the signing key alone would redirect pushes to something
# that cannot be loaded.
rm -f "$HOME/.claude/claude-auth.pub" "$HOME/.claude/settings.json"
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) exit 1 ;;
      *) printf 'ssh-ed25519 AAAATESTKEY comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test -f "$HOME/.claude/claude-signing.pub"
test ! -e "$HOME/.claude/claude-auth.pub"
test ! -e "$HOME/.claude/settings.json"

# The config must not inherit personal identities for ANY host: an alias whose
# HostName is github.com is a different Host pattern, and IdentitiesOnly does not
# exclude an explicitly configured file identity, so an included personal key would
# have been usable and would have pushed as the human account.
mkdir -p "$HOME/.ssh"
cat > "$HOME/.ssh/config" <<'EOF'
Host gh-work
	HostName github.com
	IdentityFile ~/.ssh/personal_github
Host somehost
	User personaluser
Host *
	IdentityAgent ~/Library/onepassword.sock
EOF
agent_sock="$(ssh -F "$HOME/.claude/ssh_config" -G github.com </dev/null 2>/dev/null | awk '$1=="identityagent"{print $2}')"
case "$agent_sock" in */.claude/run/agent.sock) ;; *) echo "unexpected agent socket: $agent_sock" >&2; exit 1 ;; esac
for h in github.com gh-work somehost; do
  ids="$(ssh -F "$HOME/.claude/ssh_config" -G "$h" </dev/null 2>/dev/null)"
  # Exactly one identity, ours, from our agent -- no personal key, no personal agent.
  test "$(printf '%s\n' "$ids" | grep -c '^identityfile ')" = 1
  printf '%s\n' "$ids" | grep -Fq "identityfile $HOME/.claude/claude-auth.pub"
  test "$(printf '%s\n' "$ids" | awk '$1=="identityagent"{print $2}')" = "$agent_sock"
  test "$(printf '%s\n' "$ids" | awk '$1=="identitiesonly"{print $2}')" = 'yes'
  # And nothing is inherited from the personal config at all.
  if printf '%s\n' "$ids" | grep -Fq 'onepassword.sock'; then echo "inherited the personal agent for $h" >&2; exit 1; fi
  if printf '%s\n' "$ids" | grep -Fq 'personal_github'; then echo "inherited a personal key for $h" >&2; exit 1; fi
done
test "$(ssh -F "$HOME/.claude/ssh_config" -G somehost </dev/null 2>/dev/null | awk '$1=="user"{print $2}')" != 'personaluser'
test "$(ssh -F "$HOME/.claude/ssh_config" -G github.com </dev/null 2>/dev/null | awk '$1=="user"{print $2}')" = 'git'

# A rotated signing key must not leave the old one trusted forever -- if it was
# rotated because it leaked, its holder could keep producing commits that verify
# locally as jodok@batlogg.com. The user's own signers survive the rewrite.
grep -Fq 'AAAAPERSONAL' "$HOME/.config/git/allowed_signers"
printf 'someone@else.example ssh-ed25519 AAAAUNRELATED\n' >> "$HOME/.config/git/allowed_signers"
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) printf 'ssh-ed25519 AAAAAUTHKEY comment' ;;
      *) printf 'ssh-ed25519 AAAAROTATED comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'AAAAROTATED' "$HOME/.config/git/allowed_signers"
test "$(grep -Fc 'AAAATESTKEY' "$HOME/.config/git/allowed_signers")" = 0
grep -Fq 'AAAAPERSONAL' "$HOME/.config/git/allowed_signers"
grep -Fq 'AAAAUNRELATED' "$HOME/.config/git/allowed_signers"

# Both keys again -- the block above deliberately left the identity incomplete, and
# with it incomplete the settings merge does not run at all, which would make every
# assertion below pass without exercising anything.
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) printf 'ssh-ed25519 AAAAAUTHKEY comment' ;;
      *) printf 'ssh-ed25519 AAAATESTKEY comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test -f "$HOME/.claude/claude-auth.pub"

# Our hook may end up folded into an entry the user also uses for their own commands.
# Re-running must remove only our hook object, not the entry: dropping the whole entry
# would silently delete their sibling commands and the matcher along with it. Both
# merge paths have to agree, so each is exercised.
ourcmd="$(cat "$HOME/.claude/settings-hook.installed")"
for tool in jq python3; do
  jq -n --arg ours "$ourcmd" '{hooks:{SessionStart:[
      {matcher:"startup",hooks:[{type:"command",command:"echo sibling"},{type:"command",command:$ours}]},
      {hooks:[{type:"command",command:"echo lonely"}]}]}}' > "$HOME/.claude/settings.json"
  CLAUDE_JSON_TOOL="$tool" "$ROOT_DIR/install.sh" >/dev/null
  test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("echo sibling"))) | length' "$HOME/.claude/settings.json")" = 1
  test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("echo lonely"))) | length' "$HOME/.claude/settings.json")" = 1
  test "$(jq -r '[.hooks.SessionStart[] | select(.matcher == "startup")] | length' "$HOME/.claude/settings.json")" = 1
  test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("claude-ssh-agent"))) | length' "$HOME/.claude/settings.json")" = 1
done

# An entry that held nothing but our hook is removed rather than left behind empty.
jq -n --arg ours "$ourcmd" '{hooks:{SessionStart:[{hooks:[{type:"command",command:$ours}]}]}}' \
  > "$HOME/.claude/settings.json"
"$ROOT_DIR/install.sh" >/dev/null
test "$(jq -r '.hooks.SessionStart | length' "$HOME/.claude/settings.json")" = 1

# A user hook that merely mentions claude-ssh-agent -- a wrapper, a monitor -- is not
# ours and must survive, including on a first run with no marker recorded yet.
for tool in jq python3; do
  rm -f "$HOME/.claude/settings-hook.installed"
  jq -n '{hooks:{SessionStart:[{hooks:[
      {type:"command",command:"~/bin/watch-claude-ssh-agent --verbose"}]}]}}' \
    > "$HOME/.claude/settings.json"
  CLAUDE_JSON_TOOL="$tool" "$ROOT_DIR/install.sh" >/dev/null
  test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("watch-claude-ssh-agent"))) | length' "$HOME/.claude/settings.json")" = 1
  test "$(jq -r '[.hooks.SessionStart[].hooks[].command] | map(select(test("claude-ssh-agent"))) | length' "$HOME/.claude/settings.json")" = 2
done

# GIT_CONFIG_GLOBAL replaces git's XDG global config as well as ~/.gitconfig, so the
# managed config has to include it or every agent session silently loses credential
# helpers, url rewrites and aliases. Resolved at install time, so a custom
# XDG_CONFIG_HOME has to be honoured too.
grep -Fq "path = $HOME/.config/git/config" "$HOME/.claude/gitconfig.xdg"
XDG_CONFIG_HOME="$HOME/elsewhere" "$ROOT_DIR/install.sh" >/dev/null
grep -Fq "path = $HOME/elsewhere/git/config" "$HOME/.claude/gitconfig.xdg"

# ...and the value actually resolves through the managed config.
mkdir -p "$HOME/elsewhere/git"
printf '[alias]\n\tzzz = status\n' > "$HOME/elsewhere/git/config"
printf '[alias]\n\tyyy = log\n' > "$HOME/.gitconfig"
mkdir -p "$HOME/repo" && git -C "$HOME/repo" init -q
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get alias.zzz)" = 'status'
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get alias.yyy)" = 'log'
"$ROOT_DIR/install.sh" >/dev/null

# The socket path is fixed rather than configurable -- an override would be settable
# by any repository through .claude/settings.json, and ssh_config could not honour it
# anyway -- but a leftover regular file at that path must not be chmodded and unlinked
# on the way to creating the socket.
mkdir -p "$HOME/.claude/run"
printf 'precious\n' > "$HOME/.claude/run/agent.sock"
if "$HOME/.claude/bin/claude-ssh-agent" >/dev/null 2>&1; then
  echo "loader replaced a non-socket at its own path" >&2; exit 1
fi
grep -Fq 'precious' "$HOME/.claude/run/agent.sock"
rm -f "$HOME/.claude/run/agent.sock"
# All three scripts must name the same socket, or a session signs against one agent
# while every push looks for another.
test "$(grep -c 'CLAUDE_SSH_AUTH_SOCK' "$HOME/.claude/bin/claude-ssh-agent" "$HOME/.claude/bin/claude-ssh-sign" | awk -F: '{n+=$2} END{print n}')" = 0
grep -Fq '.claude/run/agent.sock' "$HOME/.claude/ssh_config"
grep -Fq '.claude/run/agent.sock' "$HOME/.claude/bin/claude-ssh-agent"
grep -Fq '.claude/run/agent.sock' "$HOME/.claude/bin/claude-ssh-sign"

# A half-successful provisioning run must not leave a mixed generation on disk: the
# activation guard only tests that both files exist, so a new signing key beside the
# previous auth key would look complete and would fail every push after a rotation.
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) exit 1 ;;
      *) printf 'ssh-ed25519 AAAANEWSIGNING comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
test "$(grep -Fc 'AAAANEWSIGNING' "$HOME/.claude/claude-signing.pub")" = 0
grep -Fq 'AAAAAUTHKEY' "$HOME/.claude/claude-auth.pub"

# A retirement that fails must stay pending. Recording the new key anyway would make
# the next run compare it against itself and never try again, so a key rotated because
# it leaked would keep verifying forever.
cat > "$TEST_DIR/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) exit 0 ;;
  read)
    case "$2" in
      *claude-auth*) printf 'ssh-ed25519 AAAAAUTHKEY comment' ;;
      *) printf 'ssh-ed25519 AAAAGENONE comment' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/op"
"$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'AAAAGENONE' "$HOME/.config/git/allowed_signers"

# Rotate, with the signers directory read-only so the rewrite cannot happen.
sed -i.bak 's/AAAAGENONE/AAAAGENTWO/' "$TEST_DIR/bin/op"
chmod 500 "$HOME/.config/git"
"$ROOT_DIR/install.sh" >/dev/null
chmod 700 "$HOME/.config/git"
grep -Fq 'AAAAGENONE' "$HOME/.config/git/allowed_signers"   # still trusted, as reported
grep -Fq 'AAAAGENTWO' "$HOME/.config/git/allowed_signers"

# The next run, with the directory writable again, must still retire it.
"$ROOT_DIR/install.sh" >/dev/null
test "$(grep -Fc 'AAAAGENONE' "$HOME/.config/git/allowed_signers")" = 0
grep -Fq 'AAAAGENTWO' "$HOME/.config/git/allowed_signers"
grep -Fq 'AAAAPERSONAL' "$HOME/.config/git/allowed_signers"

# Files that git and ssh execute from must not carry home-relative paths: a repository
# can set HOME through its own .claude/settings.json, and a ~ in gpg.ssh.program or
# core.sshCommand would then resolve inside the repository, so a plain commit or push
# would run a file that repository supplied.
for f in "$HOME/.claude/gitconfig" "$HOME/.claude/ssh_config"; do
  if grep -v '^[[:space:]]*#' "$f" | grep -Fq '~/'; then
    echo "$f still has a home-relative path in a directive" >&2; exit 1
  fi
done
grep -Fq "$HOME/.claude/bin/claude-ssh-sign" "$HOME/.claude/gitconfig"
grep -Fq "$HOME/.claude/ssh_config" "$HOME/.claude/gitconfig"
grep -Fq "$HOME/.claude/run/agent.sock" "$HOME/.claude/ssh_config"
# The hook this installer wrote, identified exactly rather than by substring, since a
# user hook may legitimately mention the same name.
test "$(cut -c1 < "$HOME/.claude/settings-hook.installed")" = '/'
test "$(jq -r --arg ours "$(cat "$HOME/.claude/settings-hook.installed")" '[.hooks.SessionStart[].hooks[].command] | map(select(. == $ours)) | length' "$HOME/.claude/settings.json")" = 1
# Comments keep their ~, so the installed file still reads as documentation.
grep -q '^#.*~/' "$HOME/.claude/gitconfig"

# Expanding before the comparison is what keeps the install idempotent; expanding
# after would make every run see a difference and leave another backup behind.
baks_before="$(ls "$HOME/.claude" | grep -c 'gitconfig.bak' || true)"
"$ROOT_DIR/install.sh" >/dev/null
baks_after="$(ls "$HOME/.claude" | grep -c 'gitconfig.bak' || true)"
test "$baks_before" = "$baks_after"

# ...and it still resolves as a git config.
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get gpg.ssh.program)" = "$HOME/.claude/bin/claude-ssh-sign"

# An https remote must not slip past the identity: core.sshCommand governs the ssh
# transport only, so without a rewrite git would fall back to the credential helpers
# inherited from the personal config and push as the human account.
GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get-all url.git@github.com:.insteadOf | grep -Fxq 'https://github.com/'
git -C "$HOME/repo" remote add origin https://github.com/jodok/dotfiles.git 2>/dev/null || true
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" remote get-url origin)" = 'git@github.com:jodok/dotfiles.git'

# The loader and the signing shim must name the same absolute socket the ssh config
# does; deriving it from runtime HOME would let a repository that sets HOME point the
# hook at one socket while every push looked at another.
for f in "$HOME/.claude/bin/claude-ssh-agent" "$HOME/.claude/bin/claude-ssh-sign"; do
  if grep -v '^[[:space:]]*#' "$f" | grep -Fq '$HOME/'; then
    echo "$f still derives paths from runtime HOME" >&2; exit 1
  fi
  grep -Fq "$HOME/.claude/run/agent.sock" "$f"
done

# PATH is repository-settable for the hook this loader runs from, and a
# repository-supplied ssh-add would be handed both private keys on stdin. The keys never
# touching disk is no help if the process reading them is the attacker's.
grep -Fq 'PATH="/usr/bin:/bin:/usr/sbin:/sbin:' "$HOME/.claude/bin/claude-ssh-agent"
grep -Fq 'PATH="/usr/bin:/bin:/usr/sbin:/sbin"' "$HOME/.claude/bin/claude-ssh-sign"
if grep -Fq '@OP_DIR@' "$HOME/.claude/bin/claude-ssh-agent"; then
  echo "op directory placeholder was never substituted" >&2; exit 1
fi
mkdir -p "$TEST_DIR/hostile"
cat > "$TEST_DIR/hostile/ssh-add" <<'EOF'
#!/usr/bin/env bash
cat > "$TEST_DIR/hostile/stolen"
EOF
chmod +x "$TEST_DIR/hostile/ssh-add"
PATH="$TEST_DIR/hostile:$PATH" "$HOME/.claude/bin/claude-ssh-agent" >/dev/null 2>&1 || true
if [ -e "$TEST_DIR/hostile/stolen" ]; then
  echo "loader piped a key into an ssh-add found on the inherited PATH" >&2; exit 1
fi
pkill -f "ssh-agent -a $HOME/.claude/run/agent.sock" 2>/dev/null || true
rm -f "$HOME/.claude/run/agent.sock"

# insteadOf matches a literal prefix, so a userinfo form slips past it; clearing the
# helper list for GitHub means what survives has nothing to authenticate with.
test -z "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get-urlmatch credential.helper https://jodok@github.com/org/repo)"
test -z "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get-urlmatch credential.helper https://github.com/org/repo)"
# ...while other hosts keep the helpers inherited from the personal config.
printf '[credential]\n\thelper = osxkeychain\n' >> "$HOME/.gitconfig"
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get-urlmatch credential.helper https://gitlab.com/org/repo)" = 'osxkeychain'
# An empty helper list still leaves askpass and the terminal, either of which could hand
# over a personal token; a credential git cannot get from a helper must not be obtained.
test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" config --get core.askPass)" = '/usr/bin/false'
# The spellings that can be enumerated are rewritten outright.
for u in 'https://github.com/o/r.git' 'https://jodok@github.com/o/r.git' 'http://github.com/o/r.git' 'git://github.com/o/r.git'; do
  git -C "$HOME/repo" remote remove probe 2>/dev/null || true
  git -C "$HOME/repo" remote add probe "$u"
  test "$(GIT_CONFIG_GLOBAL="$HOME/.claude/gitconfig" git -C "$HOME/repo" remote get-url probe)" = 'git@github.com:o/r.git'
done

# The vault is baked at install time, not read at runtime: a repository can set the
# environment for the hook, and a runtime read would also break the documented custom
# vault workflow -- installing with CLAUDE_OP_VAULT=Work writes Work's public keys while
# a later session without that variable would look in Private.
grep -Fq 'VAULT="Private"' "$HOME/.claude/bin/claude-ssh-agent"
CLAUDE_OP_VAULT=Work "$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'VAULT="Work"' "$HOME/.claude/bin/claude-ssh-agent"
if grep -Fq '@OP_VAULT@' "$HOME/.claude/bin/claude-ssh-agent"; then
  echo "vault placeholder was never substituted" >&2; exit 1
fi
if grep -v '^[[:space:]]*#' "$HOME/.claude/bin/claude-ssh-agent" | grep -Fq 'CLAUDE_OP_VAULT'; then
  echo "loader still reads the vault from its environment" >&2; exit 1
fi
# A plain run must not re-point a non-default vault at Private: the loader is rewritten
# before the op guard, so it would be rebaked while the other vault's public keys stay
# in place -- working until the agent socket goes away, then failing everything.
"$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'VAULT="Work"' "$HOME/.claude/bin/claude-ssh-agent"
# An explicit choice still wins.
CLAUDE_OP_VAULT=Private "$ROOT_DIR/install.sh" >/dev/null
grep -Fq 'VAULT="Private"' "$HOME/.claude/bin/claude-ssh-agent"

printf 'install tests passed\n'
