# jodok/dotfiles

Portable oh-my-zsh customizations for macOS and Linux.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh)"
```

## What it does

The installer is idempotent and will:
- install oh-my-zsh if missing
- honor non-default `ZSH` and `ZSH_CUSTOM` locations
- ensure `~/.oh-my-zsh/custom/themes/jodok.zsh-theme` exists
- install `exports.zsh` to `~/.oh-my-zsh/custom/exports.zsh`
- install `aliases.zsh` to `~/.oh-my-zsh/custom/aliases.zsh`
- install `update.sh` to `~/.oh-my-zsh/custom/update.sh`
- install `update-check.zsh` to `~/.oh-my-zsh/custom/update-check.zsh`
- install `agents/global-rules.md` to `~/.agents/global-rules.md`
- install `agents/claude.md` to `~/.claude/CLAUDE.md`
- link `~/.codex/AGENTS.md` to `~/.agents/global-rules.md`
- install `claude/gitconfig`, `claude/ssh_config` and `claude/bin/*` under
  `~/.claude/`, the git identity coding agents commit and push with
- write `~/.claude/claude-signing.pub` and `~/.claude/claude-auth.pub` from the
  matching items in 1Password — the agent loader compares what it holds against
  these, so a rotated key is noticed without calling 1Password every session, and add
  that key to `~/.config/git/allowed_signers` if it is not already listed. Your own
  signers are never touched: only the exact line a previous install recorded writing
  is retired, so a rotated key stops being trusted instead of staying valid forever. Skipped with a note when the 1Password
  CLI is missing or signed out; no private key is ever written to disk
- merge two keys into `~/.claude/settings.json` — **only once a signing key
  exists**, since the config it selects sets `commit.gpgsign` and activating it
  without a key would leave git unable to commit at all — so the identity is the
  default
  rather than something to remember on every command: `env.GIT_CONFIG_GLOBAL`,
  and a `SessionStart` hook that loads the keys into the agent. **Merged, never
  rewritten** — your theme, your other settings and your own SessionStart hooks
  survive, and a re-run adds no second copy. A settings file that is not valid
  JSON is left untouched rather than replaced
- back up any differing existing file before replacing it, using `<file>.bak`
  and then numbered `<file>.bak.N` paths so an earlier backup is never replaced
- patch `~/.zshrc` so it contains:
  - `export ZSH="$HOME/.oh-my-zsh"`
  - `ZSH_THEME="jodok"`
  - `zstyle ':omz:update' mode auto`
  - `COMPLETION_WAITING_DOTS="true"`
  - `source $ZSH/oh-my-zsh.sh`
  - no legacy host-prepend `PROMPT=...${PROMPT}` line

## Update

```bash
oh-my-jodok
```

Equivalent to:

```bash
~/.oh-my-zsh/custom/update.sh
```

Interactive shells also check for a new `main` revision every 13 days. The
check is local until it is due; when GitHub reports a new revision,
oh-my-jodok automatically runs the idempotent installer from that exact
commit. To change the interval or disable automatic updates, add one of these
to `~/.oh-my-jodok.zsh`:

```zsh
zstyle ':omj:update' frequency 7
zstyle ':omj:update' mode disabled
```

## Default layout on target machine

```text
~/.oh-my-zsh/custom/
  aliases.zsh
  exports.zsh
  update-check.zsh
  update.sh
  themes/
    jodok.zsh-theme
~/.agents/
  global-rules.md      # shared rules for all coding agents
claude/                # installed to ~/.claude/
  gitconfig            # the identity agents commit and push with (managed: do not
                       #   `git config --global` into it; put durable settings in
                       #   ~/.gitconfig, which it includes)
  ssh_config           # every git remote via the agent's own ssh-agent; does not
                       #   include ~/.ssh/config, so ssh aliases do not apply
  bin/claude-ssh-agent # loads the keys from 1Password into a plain ssh-agent;
                       #   one rebuild at a time, under ~/.claude/run/agent.lock
  bin/claude-ssh-sign  # pins SSH_AUTH_SOCK for ssh-keygen when git signs
```

`CLAUDE_JSON_TOOL` picks which tool merges `settings.json` — `auto` (default,
prefers `jq`), `jq`, or `python3`. `CLAUDE_OP_VAULT` names the 1Password vault
(default `infra-hosts`) — it is baked into the installed loader, so re-run the installer
to change it rather than exporting it in a session. It is a shared vault rather than
`Private` on purpose: a 1Password service account cannot be granted access to a personal
vault, so keys kept there can only be loaded during an interactive unlock.

```
~/.claude/CLAUDE.md    # imports ~/.agents/global-rules.md
~/.codex/AGENTS.md     # symlink to ~/.agents/global-rules.md
```

## Agent rules

`agents/global-rules.md` holds reusable personal defaults every coding agent
must follow. Repository architecture, commands, lifecycle, review gates, and
deployment policy live in each repository's `AGENTS.md`, not here.
`agents/claude.md` is the minimal Claude Code adapter: it imports the shared
defaults and adds only Claude-specific mechanics. Both files are deployed by
the installer — edit them in this repo, then re-run the installer (or
`oh-my-jodok`) to roll them out.

## Local overrides

Optional local files stay outside git:
- `~/.oh-my-jodok.zsh` (oh-my-jodok update settings)
- `~/.zshrc.local`
- `~/.zshenv.local`

## Notes

- No daemon or background job; the due check runs during interactive shell
  startup.
- Uses standard oh-my-zsh auto-loading for `custom/*.zsh`.
- Secrets do not belong in this repo.

## Separate agent Git readers

The existing shell installer remains compatible with the legacy Claude setup.
An explicit reader cutover uses `agents/git/install.py` with Python 3.11+ and
exact IDs. Provision the two shared vaults and read-only service accounts first:
`agent-git-claude` contains only Claude's pair; `agent-git-codex` contains a
separate Codex pair. Neither service account needs Fleet/runtime credentials or
access to the other vault. Keep token recovery with the independent operator.

```sh
python3 agents/git/install.py --agent codex \
  --account ACCOUNT_ID --principal SERVICE_ACCOUNT_ID --vault VAULT_ID \
  --signing-item SIGNING_ITEM_ID --auth-item AUTH_ITEM_ID
```

Supply that identity's `OP_SERVICE_ACCOUNT_TOKEN` through the existing secure
provisioning environment. Never paste its value into the command, source tree
or terminal output. This command checks the account/principal and public pair,
then installs files under `~/.codex/agent-git/` (or `~/.claude/agent-git/`). It
does not change the provider configuration until explicitly called with
`--activate`. Repeating the same installation is safe; changing a pinned reader
or pair requires a separately reviewed rotation/cutover.

Each agent gets an independent fixed socket, SSH transport, signing shim and
Git config. The wrappers use an absolute Python path with isolated mode and
system SSH tools. The loader only reads the two pinned item IDs under its
pinned service account. It never retries as the operator or chooses a different
vault from repository environment variables. Private keys stream from
1Password to `ssh-add` without touching disk. A warm socket avoids repeated
reads but is not proof that a token still works; acceptance must use a cold
socket with the desktop/operator session unavailable. This is cloud reader
separation, not Unix process isolation: agents sharing one local user can still
reach each other's user-owned sockets and files.

Register the distinct public keys on GitHub, cold-load both identities, verify
signatures, and test authenticated pushes on disposable task branches **before
activation or retirement**. The installer itself cannot establish GitHub key
registration. Preserve the old working loader/token until these tests and
independent recovery succeed. Do not archive old key items and call their
access revoked; verify the source copies and old broad credentials can no
longer be read. A still-loaded SSH key is not revoked by revoking a vault token.

`--activate` changes only the agent's Git/token environment. Claude's settings
and user hooks are preserved; its recorded old loader hook is replaced. Codex's
TOML is parsed before and after the edit and unrelated settings are preserved.
Restrictive environment filters or unsupported configuration forms require an
explicit review rather than widening them. Codex uses the documented
[`shell_environment_policy.set`](https://learn.chatgpt.com/docs/config-file/config-reference)
keys; inclusion filters may otherwise remove those variables. New sessions must
be started to receive the changed environment. Signing and transport wrappers
cold-load on demand, so Codex needs no invented startup hook.

Ordinary `install.sh` runs preserve a reader installed this way, including its
provider settings. Update an explicit reader with this script and the same
verified IDs; the legacy installer does not silently replace it. No change is
made to personal shell Git/SSH configuration or the other agent's settings.

Run `python3 -m unittest discover -s tests -p 'test_*.py' -v` for hermetic reader
contracts, including real disposable SSH keys and a verified signed fixture
commit. These fixtures never contact 1Password or GitHub. The `Tests` CI check
also retains the existing shell installer/update suites.
