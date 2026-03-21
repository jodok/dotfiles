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
- install your custom files into `~/.oh-my-zsh/custom/jodok/`
- patch `~/.zshrc` so it contains:
  - `ZSH_THEME="jodok"`
  - `zstyle ':omz:update' mode auto`
  - `COMPLETION_WAITING_DOTS="true"`
- add source lines for:
  - `~/.oh-my-zsh/custom/jodok/exports.zsh`
  - `~/.oh-my-zsh/custom/jodok/functions.zsh`
  - `~/.oh-my-zsh/custom/jodok/aliases.zsh`
  - `~/.oh-my-zsh/custom/jodok/prompt.zsh`

## Update

```bash
~/.oh-my-zsh/custom/jodok/update.sh
```

Or directly:

```bash
curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh | bash
```

## Layout on target machine

```text
~/.oh-my-zsh/custom/
  jodok/
    aliases.zsh
    exports.zsh
    functions.zsh
    prompt.zsh
    update.sh
  themes/
    jodok.zsh-theme
```

## Local overrides

Optional local files stay outside git:
- `~/.zshrc.local`
- `~/.zshenv.local`

## Notes

- No daemon, no background updater.
- Secrets do not belong in this repo.
- Later we can add more aliases, functions, plugins, and package bootstrap.
