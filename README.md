# jodok/dotfiles

Portable oh-my-zsh customizations for macOS and Linux.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh)"
```

## What it does

The installer is idempotent and will:
- install oh-my-zsh if missing
- ensure `~/.oh-my-zsh/custom/themes/jodok.zsh-theme` exists
- install `exports.zsh` to `~/.oh-my-zsh/custom/exports.zsh`
- install `aliases.zsh` to `~/.oh-my-zsh/custom/aliases.zsh`
- install `update.sh` to `~/.oh-my-zsh/custom/update.sh`
- install `update-check.zsh` to `~/.oh-my-zsh/custom/update-check.zsh`
- install `agents/global-rules.md` to `~/.agents/global-rules.md`
- install `agents/claude.md` to `~/.claude/CLAUDE.md`
- link `~/.codex/AGENTS.md` to `~/.agents/global-rules.md`
- back up any differing existing file to `<file>.bak` before replacing it
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
to `~/.zshrc.local`:

```zsh
zstyle ':omj:update' frequency 7
zstyle ':omj:update' mode disabled
```

## Layout on target machine

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
~/.claude/CLAUDE.md    # imports ~/.agents/global-rules.md
~/.codex/AGENTS.md     # symlink to ~/.agents/global-rules.md
```

## Agent rules

`agents/global-rules.md` holds the git/PR workflow rules every coding agent
must follow; `agents/claude.md` adds Claude-Code-specific guidance (model
selection). Both are deployed by the installer — edit them in this repo,
then re-run the installer (or `oh-my-jodok`) to roll them out.

## Local overrides

Optional local files stay outside git:
- `~/.zshrc.local`
- `~/.zshenv.local`

## Notes

- No daemon or background job; the due check runs during interactive shell
  startup.
- Uses standard oh-my-zsh auto-loading for `custom/*.zsh`.
- Secrets do not belong in this repo.
