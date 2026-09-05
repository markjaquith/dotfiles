#!/usr/bin/env zsh
# Lazygit config symlink

mkdir -p "$HOME/Library/Application Support/lazygit"
rm -f "$HOME/Library/Application Support/lazygit/config.yml"
ln -s "$HOME/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

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
remove_git_config_values() {
	git config --global --unset-all "$@" || {
		local result=$?
		# With --unset-all, exit 5 means there were no matching values.
		(( result == 5 )) || return "$result"
	}
}

git config --global core.pager "hunk pager"
remove_git_config_values pager.diff
remove_git_config_values pager.show
remove_git_config_values pager.log
# Remove legacy delta theme include if present
remove_git_config_values --fixed-value include.path "~/.config/delta/themes/catppuccin-macchiato"

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
