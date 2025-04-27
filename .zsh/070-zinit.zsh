# if zinit exists, load it.
[[ -e /opt/homebrew/opt/zinit/zinit.zsh ]] && source /opt/homebrew/opt/zinit/zinit.zsh

# If it doesn't, error.
[[ ! -e /opt/homebrew/opt/zinit/zinit.zsh ]] && echo "zinit not found" && return 1
