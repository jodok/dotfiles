# jodok/dotfiles

Portable oh-my-zsh customizations for macOS and Linux.

## Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh)"
```

## What it does

The installer is idempotent and will:
- install oh-my-zsh if missing
- ensure `~/.oh-my-zsh/custom/themes/jodok.zsh-theme` exists
- install `exports.zsh` to `~/.oh-my-zsh/custom/exports.zsh`
- install `jodok-update.sh` to `~/.oh-my-zsh/custom/jodok-update.sh`
- patch `~/.zshrc` so it contains:
  - `ZSH_THEME="jodok"`
  - `zstyle ':omz:update' mode auto`
  - `COMPLETION_WAITING_DOTS="true"`

## Update

```bash
~/.oh-my-zsh/custom/jodok-update.sh
```

Or directly:

```bash
curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh | bash
```

## Layout on target machine

```text
~/.oh-my-zsh/custom/
  exports.zsh
  jodok-update.sh
  themes/
    jodok.zsh-theme
```

## Local overrides

Optional local files stay outside git:
- `~/.zshrc.local`
- `~/.zshenv.local`

## Notes

- No daemon, no background updater.
- No extra custom file sourcing beyond standard oh-my-zsh behavior.
- Secrets do not belong in this repo.
