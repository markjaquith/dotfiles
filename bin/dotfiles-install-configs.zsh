#!/usr/bin/env zsh
# Lazygit config symlink

mkdir -p "$HOME/Library/Application Support/lazygit"
unlink "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null
ln -s "$HOME/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml" 2>/dev/null

# Plannotator identity
if command -v jq &>/dev/null; then
	mkdir -p "$HOME/.plannotator"
	typeset plannotator_config="$HOME/.plannotator/config.json"
	typeset plannotator_config_tmp
	plannotator_config_tmp="$(mktemp "${plannotator_config}.XXXXXX")"
	jq '.displayName = "Mark"' "$plannotator_config" 2>/dev/null >| "$plannotator_config_tmp" ||
		jq -n '{ displayName: "Mark" }' >| "$plannotator_config_tmp"
	mv "$plannotator_config_tmp" "$plannotator_config"
fi

# Hunk as git pager (replaces delta)
git config --global core.pager "hunk pager"
git config --global --unset pager.diff 2>/dev/null
git config --global --unset pager.show 2>/dev/null
git config --global --unset pager.log 2>/dev/null
# Remove legacy delta theme include if present
git config --global --unset-all include.path "~/.config/delta/themes/catppuccin-macchiato" 2>/dev/null

# Agency-managed agent integrations
if command -v agency &>/dev/null && command -v jq &>/dev/null; then
	agency workbase list --json |
		jq -r '.result.workbases[].path' |
		while IFS= read -r workbase; do
			agency --workbase "$workbase" integration sync
		done
fi

# Git aliases
git config --global alias.fixup 'commit --all --amend --no-edit --no-verify'
git config --global alias.recent '!git reflog | grep "checkout: moving" | awk "!seen[\$NF]++ {print \$NF}"'

