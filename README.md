# jodok/dotfiles

Portable shell setup for macOS and Linux.

## Scope

Step 1 includes:
- zsh config
- oh-my-zsh bootstrap
- custom theme `jodok`
- aliases, exports, functions split into separate files
- idempotent installer with backups

Not included yet:
- Homebrew
- apt packages
- host-specific overrides

## Structure

```text
dotfiles/
  install.sh
  zsh/
    .zshrc
    aliases.zsh
    exports.zsh
    functions.zsh
    prompt.zsh
  oh-my-zsh/
    themes/
      jodok.zsh-theme
  bin/
```

## Install

```bash
git clone git@github.com:jodok/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Or HTTPS:

```bash
git clone https://github.com/jodok/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Behavior

The installer:
- installs oh-my-zsh if missing
- backs up existing shell files to `~/.dotfiles-backups/<timestamp>/`
- symlinks managed files into `$HOME`
- installs the `jodok` theme into oh-my-zsh custom themes
- creates optional local override files if missing

## Local overrides

These files are intentionally not managed by git and can hold machine-local or secret values:
- `~/.zshrc.local`
- `~/.zshenv.local`

They are sourced automatically when present.

## Notes

- Keep secrets out of this repo.
- Add personal scripts to `bin/` and they will be added to `PATH`.
- Later we can add Brewfile, apt support, and host-specific overlays.
