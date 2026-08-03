#!/usr/bin/env zsh
set -eo pipefail

if ! command -v jj >/dev/null 2>&1 || ! command -v fd >/dev/null 2>&1; then
	print -r -- "dotfiles overlay tests skipped (jj and fd are required)"
	exit 0
fi

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

dotfiles_dir="$test_root/dotfiles"
overlay_dir="$test_root/overlay"
mkdir -p "$dotfiles_dir/config" "$overlay_dir/config"

print -r -- "base" > "$dotfiles_dir/config/tracked"
print -r -- "other" > "$dotfiles_dir/other"
print -r -- "overlay" > "$overlay_dir/config/tracked"
print -r -- "local" > "$overlay_dir/config/local-only"

git init -q "$dotfiles_dir"
git -C "$dotfiles_dir" config user.email test@example.com
git -C "$dotfiles_dir" config user.name Test
git -C "$dotfiles_dir" add .
git -C "$dotfiles_dir" commit -qm base
jj git init --colocate "$dotfiles_dir" >/dev/null

# Start in the legacy Git-only state to exercise jj sparse migration.
rm "$dotfiles_dir/config/tracked"
ln -s "$overlay_dir/config/tracked" "$dotfiles_dir/config/tracked"
git -C "$dotfiles_dir" update-index --skip-worktree -- config/tracked

run_overlay() {
	DOTFILES_DIR="$dotfiles_dir" \
		LOCAL_DOTFILES_DIR="$overlay_dir" \
		DOTFILES_PURE="${1:-0}" \
		zsh -c "source ${(q)repo_root}/bin/dotfiles-install-overlay.zsh"
}

assert_link() {
	local path="$1"
	local target="$2"

	if [[ ! -L "$path" || "${path:A}" != "${target:A}" ]]; then
		print -ru2 -- "FAIL: expected $path to link to $target"
		exit 1
	fi
}

assert_clean() {
	if [[ -n "$(git -C "$dotfiles_dir" status --short)" ]]; then
		print -ru2 -- "FAIL: Git working copy is dirty"
		git -C "$dotfiles_dir" status --short >&2
		exit 1
	fi

	if [[ "$(jj -R "$dotfiles_dir" status)" != *"The working copy has no changes."* ]]; then
		print -ru2 -- "FAIL: jj working copy is dirty"
		jj -R "$dotfiles_dir" status >&2
		exit 1
	fi
}

run_overlay
assert_link "$dotfiles_dir/config/tracked" "$overlay_dir/config/tracked"
assert_link "$dotfiles_dir/config/local-only" "$overlay_dir/config/local-only"
assert_clean

print -r -- "changed locally" > "$overlay_dir/config/tracked"
assert_clean

run_overlay 1
if [[ -L "$dotfiles_dir/config/tracked" || "$(<"$dotfiles_dir/config/tracked")" != "base" ]]; then
	print -ru2 -- "FAIL: pure mode did not restore the tracked base file"
	exit 1
fi
if [[ -e "$dotfiles_dir/config/local-only" || -L "$dotfiles_dir/config/local-only" ]]; then
	print -ru2 -- "FAIL: pure mode did not remove the overlay-only file"
	exit 1
fi
if [[ "$(jj -R "$dotfiles_dir" sparse list)" != "." ]]; then
	print -ru2 -- "FAIL: pure mode did not reset jj sparse patterns"
	exit 1
fi
assert_clean

run_overlay
assert_link "$dotfiles_dir/config/tracked" "$overlay_dir/config/tracked"
assert_link "$dotfiles_dir/config/local-only" "$overlay_dir/config/local-only"
assert_clean

run_overlay 1
(cd "$dotfiles_dir" && jj sparse set --clear --add config/tracked) >/dev/null
if run_overlay 2>"$test_root/custom-sparse.err"; then
	print -ru2 -- "FAIL: custom jj sparse patterns were overwritten"
	exit 1
fi
if [[ "$(<"$test_root/custom-sparse.err")" != *"Refusing to replace custom jj sparse patterns"* ]]; then
	print -ru2 -- "FAIL: custom sparse pattern error was not reported"
	exit 1
fi
if grep -Fq "# BEGIN DOTFILES OVERLAY" "$dotfiles_dir/.git/info/exclude"; then
	print -ru2 -- "FAIL: custom sparse refusal changed Git exclude state"
	exit 1
fi

print -r -- "dotfiles overlay tests passed"
