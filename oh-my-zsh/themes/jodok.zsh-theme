setopt prompt_subst

PROMPT=''

if [[ "$EUID" -eq 0 ]]; then
  PROMPT='%{$fg[yellow]%}%n@%{$fg[red]%}%m%{$reset_color%} '
elif [[ "$USER" != "jodok" && "$USER" != "admin" ]]; then
  PROMPT='%{$fg[yellow]%}%n@%{$fg[red]%}%m%{$reset_color%} '
else
  PROMPT='%{$fg[red]%}%m%{$reset_color%} '
fi

PROMPT+='%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) '
PROMPT+='%{$fg[cyan]%}%c%{$reset_color%} '
PROMPT+='$(git_prompt_info) '
