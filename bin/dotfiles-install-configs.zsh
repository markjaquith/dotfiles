#!/usr/bin/env zsh
# Lazygit config symlink

mkdir -p "$HOME/Library/Application Support/lazygit"
unlink "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null
ln -s "$HOME/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null

# Delta configuration
if ! git config --global --get-regexp 'include\.path.*delta' >/dev/null 2>&1; then
	git config --global --add include.path "~/.config/delta/themes/catppuccin-macchiato" >/dev/null 2>&1
fi