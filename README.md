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
- install `colors.zsh` to `~/.oh-my-zsh/custom/colors.zsh`
- install `update.sh` to `~/.oh-my-zsh/custom/update.sh`
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

## Layout on target machine

```text
~/.oh-my-zsh/custom/
  aliases.zsh
  colors.zsh
  exports.zsh
  update.sh
  themes/
    jodok.zsh-theme
```

## Local overrides

Optional local files stay outside git:
- `~/.zshrc.local`
- `~/.zshenv.local`

## Color behavior

`colors.zsh` refreshes appearance-aware CLI defaults before each prompt so
newly launched tools can follow terminal or macOS light/dark changes:
- `BAT_THEME` uses `OneHalfDark` or `OneHalfLight`
- `FZF_DEFAULT_OPTS` uses terminal default foreground/background colors

Optional overrides:
- `DOTFILES_APPEARANCE=dark` or `DOTFILES_APPEARANCE=light`
- `DOTFILES_AUTO_APPEARANCE_COLORS=0`
- `DOTFILES_MANAGE_FZF_COLORS=0`
- `DOTFILES_BAT_THEME_DARK=...`
- `DOTFILES_BAT_THEME_LIGHT=...`

## Notes

- No daemon, no background updater.
- Uses standard oh-my-zsh auto-loading for `custom/*.zsh`.
- Secrets do not belong in this repo.
