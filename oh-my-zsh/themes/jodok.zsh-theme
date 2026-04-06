setopt prompt_subst

prompt_identity=''

if [[ "$EUID" -eq 0 ]]; then
  prompt_identity='%{$fg[yellow]%}%n@%{$fg[red]%}%m%{$reset_color%} '
elif [[ "$USER" != "jodok" && "$USER" != "admin" ]]; then
  prompt_identity='%{$fg[yellow]%}%n@%{$fg[red]%}%m%{$reset_color%} '
else
  prompt_identity='%{$fg[red]%}%m%{$reset_color%} '
fi

PROMPT="${prompt_identity}%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%} \$(git_prompt_info) "
