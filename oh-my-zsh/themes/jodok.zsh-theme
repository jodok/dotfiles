setopt prompt_subst

local prompt_user=''
if [[ "$USER" != "jodok" && "$USER" != "admin" ]]; then
  prompt_user='%{$fg[yellow]%}%n@%{$reset_color%}'
fi

PROMPT='${prompt_user}%{$fg[red]%}%m%{$reset_color%} '
PROMPT+='%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) '
PROMPT+='%{$fg[cyan]%}%c%{$reset_color%} '
PROMPT+='$(git_prompt_info) '
