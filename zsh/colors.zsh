# Appearance-aware CLI color defaults.
#
# These settings are refreshed before each prompt so an already-open shell can
# follow terminal or macOS light/dark changes for tools launched afterward.

_dotfiles_appearance_is_dark() {
  emulate -L zsh

  case "${DOTFILES_APPEARANCE:-auto}" in
    dark) return 0 ;;
    light) return 1 ;;
  esac

  if [[ -n "${COLORFGBG:-}" ]]; then
    local bg="${COLORFGBG##*;}"
    case "$bg" in
      0|1|2|3|4|5|6|8) return 0 ;;
      7|9|10|11|12|13|14|15) return 1 ;;
    esac
  fi

  if [[ "$OSTYPE" == darwin* ]] && command -v defaults >/dev/null 2>&1; then
    defaults read -g AppleInterfaceStyle >/dev/null 2>&1
    return
  fi

  return 0
}

_dotfiles_apply_appearance_colors() {
  emulate -L zsh

  [[ "${DOTFILES_AUTO_APPEARANCE_COLORS:-1}" == "0" ]] && return

  local fzf_dark='--color=fg:-1,bg:-1,hl:6,fg+:-1,bg+:8,hl+:14,prompt:2,pointer:2,marker:2,spinner:2,info:6,border:8'
  local fzf_light='--color=fg:-1,bg:-1,hl:4,fg+:-1,bg+:7,hl+:5,prompt:2,pointer:2,marker:2,spinner:2,info:4,border:8'
  local fzf_colors

  if _dotfiles_appearance_is_dark; then
    export BAT_THEME="${DOTFILES_BAT_THEME_DARK:-OneHalfDark}"
    fzf_colors="$fzf_dark"
  else
    export BAT_THEME="${DOTFILES_BAT_THEME_LIGHT:-OneHalfLight}"
    fzf_colors="$fzf_light"
  fi

  if [[ "${DOTFILES_MANAGE_FZF_COLORS:-1}" != "0" ]]; then
    if [[ -n "${_DOTFILES_LAST_FZF_COLOR_OPTS:-}" ]]; then
      FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS//$_DOTFILES_LAST_FZF_COLOR_OPTS/}"
    fi
    _DOTFILES_LAST_FZF_COLOR_OPTS="$fzf_colors"
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+${FZF_DEFAULT_OPTS} }$_DOTFILES_LAST_FZF_COLOR_OPTS"
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_apply_appearance_colors
_dotfiles_apply_appearance_colors
