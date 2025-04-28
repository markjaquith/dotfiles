#!/usr/bin/env zsh
# Lazygit config symlink

mkdir -p "$HOME/Library/Application Support/lazygit"
unlink "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null
ln -s "$HOME/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null