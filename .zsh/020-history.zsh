# Settings.
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=$HISTSIZE

# Do not save space-prefixed commands to history.
setopt hist_ignore_space

# Do not save duplicate commands to history.
HISTDUP=erase
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Append to history file.
setopt append_history

# Share history between all sessions.
setopt share_history

# Bind history search keys.
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
