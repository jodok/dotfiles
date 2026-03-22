setopt prompt_subst

prompt_user=''
if [[ "$EUID" -eq 0 ]]; then
  prompt_user='%{$fg[yellow]%}%n@%{$reset_color%}'
elif [[ "$USER" != "jodok" && "$USER" != "admin" ]]; then
  prompt_user='%{$fg[yellow]%}%n@%{$reset_color%}'
fi

PROMPT='${prompt_user}%{$fg[red]%}%m%{$reset_color%} '
PROMPT+='%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) '
PROMPT+='%{$fg[cyan]%}%c%{$reset_color%} '
PROMPT+='$(git_prompt_info) '
