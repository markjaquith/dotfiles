#!/usr/bin/env zsh
# Set up git hooks
(
	setopt errexit pipefail
	cd "$HOME/dotfiles"
	git config core.hooksPath .git/hooks
	mise install
	hk install
)
