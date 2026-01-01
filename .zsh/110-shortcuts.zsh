# Open buffer line in editor
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^xe' edit-command-line

bindkey "[D" backward-word
bindkey "[C" forward-word
bindkey "^[a" beginning-of-line
bindkey "^[e" end-of-line