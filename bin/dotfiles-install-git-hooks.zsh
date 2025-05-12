#!/usr/bin/env zsh
# Set up git hooks
(cd $HOME/dotfiles && git config core.hooksPath .git/hooks)
mise install > /dev/null 2>&1
hk install > /dev/null 2>&1

