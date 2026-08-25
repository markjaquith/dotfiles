#!/usr/bin/env zsh
# Reconcile links left by the legacy root-level and HOME Stow packages.

emulate -L zsh
setopt typeset_silent

typeset dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
typeset -a dotfiles_entries
dotfiles_entries=("${(@f)$(command ls -1A "$dotfiles_dir" 2>/dev/null)}")

typeset has_upper_home=0
typeset has_lower_home=0
typeset entry
for entry in "${dotfiles_entries[@]}"; do
	[[ "$entry" == "HOME" ]] && has_upper_home=1
	[[ "$entry" == "home" ]] && has_lower_home=1
done

if [[ "$has_upper_home" == "1" && "$has_lower_home" == "1" ]]; then
	print -u2 "Error: Both $dotfiles_dir/HOME and $dotfiles_dir/home exist"
	print -u2 "Reconcile them manually before running dotfiles"
	return 1
fi

if [[ "$has_upper_home" == "1" ]]; then
	typeset case_migration_dir="$dotfiles_dir/.home-case-migration"
	if [[ -e "$case_migration_dir" || -L "$case_migration_dir" ]]; then
		print -u2 "Error: Temporary migration path already exists: $case_migration_dir"
		return 1
	fi
	mv "$dotfiles_dir/HOME" "$case_migration_dir" || return 1
	mv "$case_migration_dir" "$dotfiles_dir/home" || return 1
fi

legacy_dotfiles_link() {
	typeset link_path="$1"
	[[ -L "$link_path" ]] || return 1

	typeset link_target resolved_target
	link_target=$(readlink "$link_path" 2>/dev/null) || return 1
	if [[ "$link_target" == /* ]]; then
		resolved_target="${link_target:A}"
	else
		resolved_target="${link_path:h}/$link_target"
		resolved_target="${resolved_target:A}"
	fi

	[[ "$resolved_target" == "$dotfiles_dir/HOME"/* ]] && return 0

	typeset root
	for root in .agents .claude .config .p10k.zsh .pi .playwright-mcp .vimrc \
		.zlogin .zlogin-e .zsh .zshrc .zshrc-e; do
		[[ "$resolved_target" == "$dotfiles_dir/$root" || \
			"$resolved_target" == "$dotfiles_dir/$root"/* ]] && return 0
	done

	return 1
}

cleanup_legacy_link() {
	typeset link_path="$1"
	legacy_dotfiles_link "$link_path" || return 0
	print "Removing legacy dotfiles link: $link_path"
	rm -f "$link_path"
}

typeset home_path nested_link
for entry in .agents .claude .config .p10k.zsh .pi .playwright-mcp .vimrc \
	.zlogin .zlogin-e .zsh .zshrc .zshrc-e AGENTS.md; do
	home_path="$HOME/$entry"
	if [[ -L "$home_path" ]]; then
		cleanup_legacy_link "$home_path"
	elif [[ -d "$home_path" ]]; then
		while IFS= read -r nested_link; do
			cleanup_legacy_link "$nested_link"
		done < <(find "$home_path" -type l -print 2>/dev/null)
	fi
done

if [[ -L "$HOME/bin" ]]; then
	typeset bin_target
	bin_target=$(readlink "$HOME/bin" 2>/dev/null)
	if [[ "$bin_target" == "dotfiles/bin" || "${bin_target:A}" == "$dotfiles_dir/bin" ]]; then
		print "Removing redundant dotfiles link: $HOME/bin"
		rm -f "$HOME/bin"
	fi
fi
