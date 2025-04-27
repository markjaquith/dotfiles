# Enable default zsh completions.
autoload -Uz compinit

# If the completion cache is old, regenerate it.
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done

# Load cached completion if it exists.
compinit -C

# # This just needs to be immediately before one zinit command. Doesn't matter which.
zinit ice atinit'unalias zi'
zinit light g-plane/zsh-yarn-autocompletions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light jessarcher/zsh-artisan
