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
  bin/claude-ssh-agent # loads the keys from 1Password into a plain ssh-agent
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
