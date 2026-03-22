# jodok/dotfiles

Portable shell customizations for macOS and Linux.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jodok/dotfiles/main/install.sh)"
```

## What it does

The installer is idempotent and behaves differently by OS.

### macOS

- installs oh-my-zsh if missing
- ensures `~/.oh-my-zsh/custom/themes/jodok.zsh-theme` exists
- installs `zsh/exports.zsh` to `~/.oh-my-zsh/custom/exports.zsh`
- installs `zsh/aliases.zsh` to `~/.oh-my-zsh/custom/aliases.zsh`
- installs `update.sh` to `~/.oh-my-zsh/custom/update.sh`
- patches `~/.zshrc` so it contains:
  - `export ZSH="$HOME/.oh-my-zsh"`
  - `ZSH_THEME="jodok"`
  - `zstyle ':omz:update' mode auto`
  - `COMPLETION_WAITING_DOTS="true"`
  - `source $ZSH/oh-my-zsh.sh`

### Linux

- installs bash config to `~/.jodok/bashrc`
- installs `update.sh` to `~/.jodok/update.sh`
- patches `~/.bashrc` to source `~/.jodok/bashrc`
- sets a host-aware prompt:
  - `jodok` and `admin` show `host ➜ path`
  - `root` shows `root@host ➜ path`
  - other users show `user@host ➜ path`

## Update

On macOS:

```bash
oh-my-jodok
```

On Linux:

```bash
~/.jodok/update.sh
```

## Layout on target machine

### macOS

```text
~/.oh-my-zsh/custom/
  aliases.zsh
  exports.zsh
  update.sh
  themes/
    jodok.zsh-theme
```

### Linux

```text
~/.jodok/
  bashrc
  update.sh
```

## Local overrides

Optional local files stay outside git.

macOS:
- `~/.zshrc.local`
- `~/.zshenv.local`

Linux:
- `~/.bashrc.local`
- `~/.bash_profile.local`

## Notes

- No daemon, no background updater.
- macOS uses oh-my-zsh.
- Linux uses bash-first setup.
- Secrets do not belong in this repo.
