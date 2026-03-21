#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-jodok/dotfiles}"
BRANCH="${BRANCH:-main}"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
CUSTOM_DIR="$ZSH_DIR/custom"
THEMES_DIR="$CUSTOM_DIR/themes"
INSTALL_DIR="$CUSTOM_DIR/jodok"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}"
THEME_URL="$RAW_BASE/oh-my-zsh/themes/jodok.zsh-theme"
ALIASES_URL="$RAW_BASE/zsh/aliases.zsh"
EXPORTS_URL="$RAW_BASE/zsh/exports.zsh"
FUNCTIONS_URL="$RAW_BASE/zsh/functions.zsh"
PROMPT_URL="$RAW_BASE/zsh/prompt.zsh"
UPDATE_URL="$RAW_BASE/update.sh"

log() {
  printf '\n[%s] %s\n' "dotfiles" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is required but not installed" >&2
    exit 1
  }
}

ensure_oh_my_zsh() {
  if [ -d "$ZSH_DIR" ]; then
    log "oh-my-zsh already installed"
    return
  fi

  require_cmd git
  require_cmd curl

  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

fetch_file() {
  local url="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  curl -fsSL "$url" -o "$target"
}

patch_or_append() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"

  if grep -Eq "$pattern" "$file"; then
    perl -0pi -e "s/$pattern/$replacement/mg" "$file"
  else
    printf '\n%s\n' "$replacement" >> "$file"
  fi
}

ensure_source_line() {
  local file="$1"
  local line="$2"
  grep -Fqx "$line" "$file" || printf '\n%s\n' "$line" >> "$file"
}

patch_zshrc() {
  local zshrc="$HOME/.zshrc"
  touch "$zshrc"

  patch_or_append "$zshrc" '^([[:space:]]*export[[:space:]]+)?ZSH_THEME=.*$' 'ZSH_THEME="jodok"'
  patch_or_append "$zshrc" "^[[:space:]]*zstyle ':omz:update' mode .*$" "zstyle ':omz:update' mode auto"
  patch_or_append "$zshrc" '^[[:space:]]*COMPLETION_WAITING_DOTS=.*$' 'COMPLETION_WAITING_DOTS="true"'

  ensure_source_line "$zshrc" '[ -f "$ZSH/custom/jodok/exports.zsh" ] && source "$ZSH/custom/jodok/exports.zsh"'
  ensure_source_line "$zshrc" '[ -f "$ZSH/custom/jodok/functions.zsh" ] && source "$ZSH/custom/jodok/functions.zsh"'
  ensure_source_line "$zshrc" '[ -f "$ZSH/custom/jodok/aliases.zsh" ] && source "$ZSH/custom/jodok/aliases.zsh"'
  ensure_source_line "$zshrc" '[ -f "$ZSH/custom/jodok/prompt.zsh" ] && source "$ZSH/custom/jodok/prompt.zsh"'

  log "patched $zshrc"
}

main() {
  require_cmd zsh
  require_cmd curl

  ensure_oh_my_zsh

  mkdir -p "$INSTALL_DIR" "$THEMES_DIR"

  fetch_file "$THEME_URL" "$THEMES_DIR/jodok.zsh-theme"
  fetch_file "$ALIASES_URL" "$INSTALL_DIR/aliases.zsh"
  fetch_file "$EXPORTS_URL" "$INSTALL_DIR/exports.zsh"
  fetch_file "$FUNCTIONS_URL" "$INSTALL_DIR/functions.zsh"
  fetch_file "$PROMPT_URL" "$INSTALL_DIR/prompt.zsh"
  fetch_file "$UPDATE_URL" "$INSTALL_DIR/update.sh"
  chmod +x "$INSTALL_DIR/update.sh"

  touch "$HOME/.zshrc.local" "$HOME/.zshenv.local"
  patch_zshrc

  log "done"
  log "restart your shell or run: source ~/.zshrc"
}

main "$@"
