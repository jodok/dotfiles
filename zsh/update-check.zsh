_oh_my_jodok_update_check() {
  [[ -o interactive ]] || return

  local update_mode=auto
  local update_days=13
  local updater

  zstyle -s ':omj:update' mode update_mode || true
  zstyle -s ':omj:update' frequency update_days || true

  if [[ "$update_mode" == auto ]]; then
    updater="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/update.sh"
    if [[ -x "$updater" ]]; then
      OH_MY_JODOK_UPDATE_DAYS="$update_days" "$updater" --auto
    fi
  fi
}

_oh_my_jodok_update_check
unfunction _oh_my_jodok_update_check
