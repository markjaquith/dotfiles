# Enable default zsh completions.
autoload -Uz compinit

# If the completion cache is old, regenerate it.
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done

# Load cached completion if it exists.
compinit -C

[[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

if command -v herdr >/dev/null 2>&1; then
  source <(herdr completion zsh)
fi

# # This just needs to be immediately before one zinit command. Doesn't matter which.
zinit ice atinit'unalias zi'
zinit light g-plane/zsh-yarn-autocompletions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light jessarcher/zsh-artisan
