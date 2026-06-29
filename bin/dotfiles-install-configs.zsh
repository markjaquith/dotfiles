#!/usr/bin/env zsh
# Lazygit config symlink

mkdir -p "$HOME/Library/Application Support/lazygit"
unlink "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null
ln -s "$HOME/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null

# Hunk as git pager (replaces delta)
git config --global core.pager "hunk pager"
git config --global --unset pager.diff 2>/dev/null
git config --global --unset pager.show 2>/dev/null
git config --global --unset pager.log 2>/dev/null
# Remove legacy delta theme include if present
git config --global --unset-all include.path "~/.config/delta/themes/catppuccin-macchiato" 2>/dev/null

# Git aliases
git config --global alias.fixup 'commit --all --amend --no-edit --no-verify'
git config --global alias.recent '!git reflog | grep "checkout: moving" | awk "!seen[\$NF]++ {print \$NF}"'


