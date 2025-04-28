#!/usr/bin/env zsh
# Sesh config concatenation

mkdir -p ~/.config/sesh
cp "$DOTFILES_DIR/.config/sesh/sesh-default.toml" ~/.config/sesh/sesh.toml 2>/dev/null

if [ -f "$LOCAL_DOTFILES_DIR/.config/sesh/sesh.toml" ]; then
    cat "$LOCAL_DOTFILES_DIR/.config/sesh/sesh.toml" >> ~/.config/sesh/sesh.toml
fi