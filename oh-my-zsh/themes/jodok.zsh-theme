PROMPT='%{$fg[red]%}%m%{$reset_color%} '
PROMPT+='%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) '
PROMPT+='%{$fg[cyan]%}%c%{$reset_color%} '
PROMPT+='$(git_prompt_info) '
