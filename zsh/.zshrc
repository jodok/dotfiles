export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="jodok"

zstyle ':omz:update' mode auto
COMPLETION_WAITING_DOTS="true"

plugins=(git)

[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

[ -f "$HOME/.exports.zsh" ] && source "$HOME/.exports.zsh"
[ -f "$HOME/.functions.zsh" ] && source "$HOME/.functions.zsh"
[ -f "$HOME/.aliases.zsh" ] && source "$HOME/.aliases.zsh"
[ -f "$HOME/.prompt.zsh" ] && source "$HOME/.prompt.zsh"

# OpenClaw completion
[ -f "$HOME/.openclaw/completions/openclaw.zsh" ] && source "$HOME/.openclaw/completions/openclaw.zsh"

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
