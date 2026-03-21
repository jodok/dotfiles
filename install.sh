#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
THEME_SRC="$DOTFILES_DIR/oh-my-zsh/themes/jodok.zsh-theme"
THEME_DST_DIR="$ZSH_CUSTOM_DIR/themes"

log() {
  printf '\n[%s] %s\n' "dotfiles" "$*"
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$target" "$BACKUP_DIR/"
    log "backed up $target -> $BACKUP_DIR"
  fi
}

link_file() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  backup_if_exists "$target"
  rm -rf "$target"
  ln -s "$source" "$target"
  log "linked $target -> $source"
}

ensure_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log "oh-my-zsh already installed"
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "git is required but not installed" >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required but not installed" >&2
    exit 1
  fi

  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

ensure_local_files() {
  touch "$HOME/.zshrc.local"
  touch "$HOME/.zshenv.local"
  log "ensured local override files"
}

install_theme() {
  mkdir -p "$THEME_DST_DIR"
  cp "$THEME_SRC" "$THEME_DST_DIR/jodok.zsh-theme"
  log "installed theme to $THEME_DST_DIR/jodok.zsh-theme"
}

main() {
  log "dotfiles dir: $DOTFILES_DIR"

  if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh is required but not installed" >&2
    exit 1
  fi

  ensure_oh_my_zsh
  install_theme

  link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/zsh/aliases.zsh" "$HOME/.aliases.zsh"
  link_file "$DOTFILES_DIR/zsh/exports.zsh" "$HOME/.exports.zsh"
  link_file "$DOTFILES_DIR/zsh/functions.zsh" "$HOME/.functions.zsh"
  link_file "$DOTFILES_DIR/zsh/prompt.zsh" "$HOME/.prompt.zsh"

  ensure_local_files

  log "done"
  log "restart your shell or run: source ~/.zshrc"
}

main "$@"
