#!/usr/bin/env zsh
# Prereqs & environment setup

LOCAL_DOTFILES_DIR="$HOME/.local-dotfiles"
DOTFILES_DIR="$HOME/dotfiles"

# Suppress Homebrew messages
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

# Install bun early if not already installed
if ! command -v bun &>/dev/null; then
  brew install oven-sh/bun/bun 2>/dev/null
fi

# Handle Homebrew taps
brew tap FelixKratz/formulae
brew tap atlassian/homebrew-acli
