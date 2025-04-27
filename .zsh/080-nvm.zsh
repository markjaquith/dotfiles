# NVM (must be after zinit)
if [ -n "$DOTFILES_NVM" ]; then
	export NVM_AUTO_USE=true
	export NVM_LAZY_LOAD=true
	zinit wait lucid light-mode for lukechilds/zsh-nvm
fi;
