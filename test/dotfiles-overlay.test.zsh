#!/usr/bin/env zsh
set -eo pipefail

if ! command -v jj >/dev/null 2>&1 || ! command -v fd >/dev/null 2>&1 \
	|| ! command -v stow >/dev/null 2>&1; then
	print -r -- "dotfiles overlay tests skipped (jj, fd, and stow are required)"
	exit 0
fi

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
unset DOTFILES_OVERLAY_DIRS DOTFILES_OVERLAY_PREFLIGHT DOTFILES_OVERLAY_SNAPSHOT DOTFILES_OVERLAY_RESTORE_MAP

dotfiles_dir="$test_root/dotfiles"
overlay_dir="$test_root/overlay"
target_dir="$test_root/home"
mkdir -p "$dotfiles_dir/home/config" "$overlay_dir/home/config" "$target_dir"

print -r -- "base" > "$dotfiles_dir/home/config/tracked"
print -r -- "other" > "$dotfiles_dir/other"
print -r -- "overlay" > "$overlay_dir/home/config/tracked"
print -r -- "local" > "$overlay_dir/home/config/local-only"

git init -q "$dotfiles_dir"
git -C "$dotfiles_dir" config user.email test@example.com
git -C "$dotfiles_dir" config user.name Test
git -C "$dotfiles_dir" add .
git -C "$dotfiles_dir" commit -qm base
jj git init --colocate "$dotfiles_dir" >/dev/null

# Start in the legacy Git-only state to exercise jj sparse migration.
rm "$dotfiles_dir/home/config/tracked"
ln -s "$overlay_dir/home/config/tracked" "$dotfiles_dir/home/config/tracked"
git -C "$dotfiles_dir" update-index --skip-worktree -- home/config/tracked

run_overlay() {
	DOTFILES_DIR="$dotfiles_dir" \
		DOTFILES_TARGET_DIR="$target_dir" \
		LOCAL_DOTFILES_DIR="$overlay_dir" \
		DOTFILES_PURE="${1:-0}" \
		zsh -c "source ${(q)repo_root}/bin/dotfiles-install-overlay.zsh"
}

assert_link() {
	local link_path="$1"
	local target="$2"
	local candidate
	candidate=$(readlink "$link_path") || candidate=""
	[[ "$candidate" == /* ]] || candidate="${link_path:h}/$candidate"

	if [[ ! -L "$link_path" || "${candidate:A}" != "${target:A}" ]]; then
		print -ru2 -- "FAIL: expected $link_path to link to $target"
		[[ ! -f "$test_root/stow.out" ]] || print -ru2 -- "$(<"$test_root/stow.out")"
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
assert_link "$dotfiles_dir/home/config/tracked" "$overlay_dir/home/config/tracked"
assert_link "$dotfiles_dir/home/config/local-only" "$overlay_dir/home/config/local-only"
assert_link "$target_dir/config/local-only" "$dotfiles_dir/home/config/local-only"
assert_clean

print -r -- "changed locally" > "$overlay_dir/home/config/tracked"
assert_clean

run_overlay 1
if [[ -L "$dotfiles_dir/home/config/tracked" || "$(<"$dotfiles_dir/home/config/tracked")" != "base" ]]; then
	print -ru2 -- "FAIL: pure mode did not restore the tracked base file"
	exit 1
fi
if [[ -e "$dotfiles_dir/home/config/local-only" || -L "$dotfiles_dir/home/config/local-only" ]]; then
	print -ru2 -- "FAIL: pure mode did not remove the overlay-only file"
	exit 1
fi
if [[ -e "$target_dir/config/local-only" || -L "$target_dir/config/local-only" ]]; then
	print -ru2 -- "FAIL: pure mode did not remove the overlay-only home link"
	exit 1
fi
if [[ "$(jj -R "$dotfiles_dir" sparse list)" != "." ]]; then
	print -ru2 -- "FAIL: pure mode did not reset jj sparse patterns"
	exit 1
fi
assert_clean

run_overlay
assert_link "$dotfiles_dir/home/config/tracked" "$overlay_dir/home/config/tracked"
assert_link "$dotfiles_dir/home/config/local-only" "$overlay_dir/home/config/local-only"
assert_clean

run_overlay 1
(cd "$dotfiles_dir" && jj sparse set --clear --add home/config/tracked) >/dev/null
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

fail() {
	print -ru2 -- "FAIL: $*"
	exit 1
}

new_fixture() {
	target_dir="$test_root/$1"
	dotfiles_dir="$target_dir/dotfiles"
	overlay_dir="$target_dir/.local-dotfiles"
	mkdir -p "$dotfiles_dir/home/config" "$dotfiles_dir/bin" "$overlay_dir/home/config"
	print -r -- base > "$dotfiles_dir/home/config/tracked"
	print -r -- untouched > "$dotfiles_dir/home/config/new-tracked"
	ln -s new-tracked "$dotfiles_dir/home/config/base-link"
	print -r -- overlay > "$overlay_dir/home/config/tracked"
	print -r -- overlay-link > "$overlay_dir/home/config/base-link"
	print -r -- local > "$overlay_dir/home/config/local-only"
	print -r -- '--target=..' > "$dotfiles_dir/.stowrc"
	cp "$repo_root/bin/dotfiles" "$repo_root/bin/dotfiles-install-overlay.zsh" \
		"$repo_root/bin/dotfiles-overlay-common.zsh" "$dotfiles_dir/bin/"
	git init -q "$dotfiles_dir"
	git -C "$dotfiles_dir" config user.email test@example.com
	git -C "$dotfiles_dir" config user.name Test
	git -C "$dotfiles_dir" add .
	git -C "$dotfiles_dir" commit -qm base
	if [[ "$2" == jj ]]; then
		jj git init --colocate "$dotfiles_dir" >/dev/null
	fi
}

save_state() {
	cp "$dotfiles_dir/.git/index" "$test_root/index.before"
	cp "$dotfiles_dir/.git/info/exclude" "$test_root/exclude.before"
	if [[ -d "$dotfiles_dir/.jj" ]]; then
		jj -R "$dotfiles_dir" --ignore-working-copy sparse list > "$test_root/sparse.before"
	fi
}

assert_state_unchanged() {
	cmp -s "$test_root/index.before" "$dotfiles_dir/.git/index" || fail "preflight changed the Git index"
	cmp -s "$test_root/exclude.before" "$dotfiles_dir/.git/info/exclude" || fail "preflight changed excludes"
	if [[ -d "$dotfiles_dir/.jj" ]]; then
		[[ "$(jj -R "$dotfiles_dir" --ignore-working-copy sparse list)" == "$(<"$test_root/sparse.before")" ]] \
			|| fail "preflight changed jj sparse patterns"
	fi
}

assert_refused() {
	save_state
	if run_overlay >"$test_root/refused.out" 2>&1; then
		fail "unsafe overlay was accepted: $1"
	fi
	[[ "$(<"$test_root/refused.out")" == *"$1"* ]] || fail "missing refusal: $1"
	assert_state_unchanged
	[[ ! -e "$dotfiles_dir/home/config/local-only" ]] || fail "preflight partially applied overlays"
}

for backend in git jj; do
	for collision in dirty skipped assumed staged staged-only deleted mode untracked symlink directory parent home; do
		new_fixture "$backend-$collision" "$backend"
		case "$collision" in
			dirty|skipped|assumed|staged)
				print -r -- edited > "$dotfiles_dir/home/config/tracked"
				case "$collision" in
					skipped) git -C "$dotfiles_dir" update-index --skip-worktree home/config/tracked ;;
					assumed) git -C "$dotfiles_dir" update-index --assume-unchanged home/config/tracked ;;
					staged) git -C "$dotfiles_dir" add home/config/tracked ;;
				esac
				assert_refused "base: home/config/tracked"
				[[ "$(<"$dotfiles_dir/home/config/tracked")" == edited ]] || fail "base edit lost"
				;;
			staged-only)
				print -r -- edited > "$dotfiles_dir/home/config/tracked"
				git -C "$dotfiles_dir" add home/config/tracked
				print -r -- base > "$dotfiles_dir/home/config/tracked"
				assert_refused "staged base: home/config/tracked"
				;;
			mode)
				chmod +x "$dotfiles_dir/home/config/tracked"
				assert_refused "dirty base: home/config/tracked"
				[[ -x "$dotfiles_dir/home/config/tracked" ]] || fail "base mode edit lost"
				;;
			deleted)
				rm "$dotfiles_dir/home/config/tracked"
				assert_refused "dirty base: home/config/tracked"
				[[ ! -e "$dotfiles_dir/home/config/tracked" ]] || fail "base deletion lost"
				;;
			untracked|symlink|directory)
				print -r -- overlay > "$overlay_dir/home/config/z-collision"
				case "$collision" in
					untracked) print -r -- mine > "$dotfiles_dir/home/config/z-collision" ;;
					symlink) ln -s missing "$dotfiles_dir/home/config/z-collision" ;;
					directory) mkdir "$dotfiles_dir/home/config/z-collision" ;;
				esac
				assert_refused "collision: home/config/z-collision"
				[[ ! -L "$dotfiles_dir/home/config/tracked" ]] || fail "preflight replaced clean base"
				case "$collision" in
					untracked) [[ "$(<"$dotfiles_dir/home/config/z-collision")" == mine ]] || fail "untracked file lost" ;;
					symlink) [[ "$(readlink "$dotfiles_dir/home/config/z-collision")" == missing ]] || fail "unmanaged symlink lost" ;;
					directory) [[ -d "$dotfiles_dir/home/config/z-collision" ]] || fail "unmanaged directory lost" ;;
				esac
				;;
			parent)
				mkdir "$target_dir/outside" "$overlay_dir/home/escape"
				ln -s "$target_dir/outside" "$dotfiles_dir/home/escape"
				print -r -- overlay > "$overlay_dir/home/escape/file"
				assert_refused "parent collision:"
				[[ ! -e "$target_dir/outside/file" ]] || fail "overlay escaped checkout"
				;;
			home)
				mkdir "$target_dir/config"
				print -r -- mine > "$target_dir/config/tracked"
				assert_refused "unmanaged home collision:"
				[[ "$(<"$target_dir/config/tracked")" == mine ]] || fail "home collision overwritten"
				;;
		esac
	done
done

stow_bin=$(command -v stow)
fd_bin=$(command -v fd)
jj_bin=$(command -v jj)
# Resolve mise shims before changing HOME; fixture homes have no mise trust state.
[[ "$fd_bin" != */mise/shims/* ]] || fd_bin=$(mise which fd)
[[ "$jj_bin" != */mise/shims/* ]] || jj_bin=$(mise which jj)
run_dotfiles() {
	HOME="$target_dir" ORIGINAL_HOME="$HOME" STOW_BIN="$stow_bin" \
		FD_BIN="$fd_bin" JJ_BIN="$jj_bin" STOW_TEST_MODE="${stow_test_mode:-real}" zsh -c '
		gum() { :; }
		fd() { command "$FD_BIN" "$@"; }
		jj() { HOME="$ORIGINAL_HOME" command "$JJ_BIN" "$@"; }
		stow() {
			print -r -- "$*" >> "$HOME/stow.calls"
			case "$STOW_TEST_MODE" in
				dry-fail) return 1 ;;
				apply-fail|edit-fail|active-edit-fail)
					[[ "$1" == --simulate ]] && return 0
					if [[ "$STOW_TEST_MODE" == edit-fail ]]; then
						print -r -- edited-during-stow > "$HOME/dotfiles/home/config/new-tracked"
					elif [[ "$STOW_TEST_MODE" == active-edit-fail ]]; then
						print -r -- edited-during-stow > "$HOME/dotfiles/home/config/tracked"
					fi
					return 1
					;;
			esac
			command "$STOW_BIN" "$@"
		}
		source "$1" "${@:2}"
	' fixture "$dotfiles_dir/bin/dotfiles" "$@"
}

run_doctor() {
	DOTFILES_DIR="$dotfiles_dir" LOCAL_DOTFILES_DIR="$overlay_dir" \
		zsh "$repo_root/bin/dotfiles-overlay-doctor"
}

for backend in git jj; do
	new_fixture "$backend-external-sources" "$backend"
	print -r -- external > "$target_dir/external-file"
	ln -s missing "$target_dir/external-dangling"
	rm "$overlay_dir/home/config/"{tracked,base-link,local-only}
	ln -s "$target_dir/external-file" "$overlay_dir/home/config/tracked"
	ln -s "$target_dir/external-dangling" "$overlay_dir/home/config/base-link"
	ln -s "$target_dir/missing" "$overlay_dir/home/config/local-only"
	run_overlay
	# Relative checkout links must retain the same ownership as generated links.
	rm "$dotfiles_dir/home/config/tracked"
	ln -s ../../../.local-dotfiles/home/config/tracked "$dotfiles_dir/home/config/tracked"
	run_overlay
	stow_test_mode=real
	for attempt in 1 2; do
		run_dotfiles >"$test_root/stow.out" 2>&1 || fail "external-source dotfiles failed: $(<"$test_root/stow.out")"
		for name in tracked base-link local-only; do
			[[ "$(readlink "$dotfiles_dir/home/config/$name")" == "${overlay_dir:A}/home/config/$name" ]] \
				|| fail "overlay link bypassed its immediate source: $name"
		done
		doctor_output=$(run_doctor)
		[[ "$doctor_output" == *'active overrides:  3'* && "$doctor_output" == *'broken overrides:  2'* ]] \
			|| fail "doctor misclassified external overlay sources: $doctor_output"
		[[ "$doctor_output" == *"home/config/tracked -> ${overlay_dir:A}/home/config/tracked"* ]] \
			|| fail "doctor bypassed the immediate overlay source"
	done
	# Failed Stow recovery must also retain the intermediate overlay source links.
	stow_test_mode=dry-fail
	if run_dotfiles >"$test_root/stow.out" 2>&1; then
		fail "Stow failure returned success"
	fi
	for name in tracked base-link local-only; do
		[[ "$(readlink "$dotfiles_dir/home/config/$name")" == "${overlay_dir:A}/home/config/$name" ]] \
			|| fail "recovery bypassed its immediate source: $name"
	done
	stow_test_mode=real
	run_dotfiles --pure >"$test_root/stow.out" 2>&1 || fail "external-source pure mode failed: $(<"$test_root/stow.out")"
	[[ ! -L "$dotfiles_dir/home/config/tracked" && "$(<"$dotfiles_dir/home/config/tracked")" == base ]] || fail "pure mode lost base"
	[[ "$(readlink "$dotfiles_dir/home/config/base-link")" == new-tracked ]] || fail "pure mode lost base symlink"
	[[ ! -L "$dotfiles_dir/home/config/local-only" && ! -L "$target_dir/config/local-only" ]] || fail "pure mode retained dangling overlay"
	[[ "$(<"$target_dir/external-file")" == external && "$(readlink "$target_dir/external-dangling")" == missing ]] \
		|| fail "overlay lifecycle changed external targets"
	[[ ! -e "$target_dir/missing" && ! -L "$target_dir/missing" ]] || fail "overlay lifecycle created missing external target"
	[[ "$(readlink "$overlay_dir/home/config/tracked")" == "$target_dir/external-file" \
		&& "$(readlink "$overlay_dir/home/config/base-link")" == "$target_dir/external-dangling" \
		&& "$(readlink "$overlay_dir/home/config/local-only")" == "$target_dir/missing" ]] || fail "overlay source links changed"
	[[ "$(run_doctor)" == *'active overrides:  0'* ]] || fail "doctor retained pure-mode active overlays"
	[[ -z "$(git -C "$dotfiles_dir" status --short)" ]] || fail "external-source lifecycle dirtied Git"
	if [[ "$backend" == jj ]]; then
		[[ "$(jj -R "$dotfiles_dir" --ignore-working-copy sparse list)" == . ]] || fail "pure mode retained sparse exclusions"
	fi

	for unrelated in direct relay parent-escape; do
		new_fixture "$backend-unrelated-$unrelated" "$backend"
		print -r -- external > "$target_dir/external-file"
		ln -s "$target_dir/external-file" "$overlay_dir/home/config/z-collision"
		case "$unrelated" in
			direct) unrelated_target="$target_dir/external-file" ;;
			relay)
				ln -s "$overlay_dir/home/config/z-collision" "$target_dir/relay"
				unrelated_target="$target_dir/relay"
				;;
			parent-escape)
				ln -s "$target_dir" "$overlay_dir/home/escape"
				unrelated_target="$overlay_dir/home/escape/external-file"
				;;
		esac
		ln -s "$unrelated_target" "$dotfiles_dir/home/config/z-collision"
		assert_refused "unmanaged overlay collision: home/config/z-collision"
		[[ "$(run_doctor)" == *'active overrides:  0'* ]] || fail "doctor claimed unrelated symlink"
		run_overlay 1
		[[ "$(readlink "$dotfiles_dir/home/config/z-collision")" == "$unrelated_target" \
			&& "$(<"$target_dir/external-file")" == external ]] || fail "pure mode changed unrelated symlink or target"
	done
done

for backend in git jj; do
	for failure in real dry-fail apply-fail edit-fail; do
		for requested_mode in normal pure; do
			new_fixture "$backend-$failure-$requested_mode" "$backend"
			run_overlay
			# A disappeared source must return as its previous dangling link, too.
			rm "$overlay_dir/home/config/local-only"
			print -r -- new > "$overlay_dir/home/config/new-tracked"
			print -r -- new > "$overlay_dir/home/config/new-only"
			mkdir -p "$target_dir/config"
			if [[ "$failure" == real ]]; then
				print -r -- collision > "$target_dir/config/new-tracked"
				# This conflicts with Stow, not overlay preflight.
				rm "$overlay_dir/home/config/new-tracked"
			fi
			stow_test_mode="$failure"
			args=()
			[[ "$requested_mode" == pure ]] && args=(--pure)
			save_state
			if run_dotfiles "${args[@]}" >"$test_root/stow.out" 2>&1; then
				fail "Stow failure returned success: $backend $failure $requested_mode"
			fi
			[[ -f "$target_dir/stow.calls" ]] || fail "did not reach Stow: $(<"$test_root/stow.out")"
			if [[ "$failure" == real || "$failure" == dry-fail ]]; then
				[[ "$(<"$target_dir/stow.calls")" == '--simulate --restow home' ]] || fail "Stow applied after failed dry run"
			else
				[[ "$(<"$target_dir/stow.calls")" == $'--simulate --restow home\n--restow home' ]] || fail "Stow skipped dry run"
			fi
			assert_link "$dotfiles_dir/home/config/tracked" "$overlay_dir/home/config/tracked"
			assert_link "$dotfiles_dir/home/config/local-only" "$overlay_dir/home/config/local-only"
			assert_link "$target_dir/config/tracked" "$dotfiles_dir/home/config/tracked"
			assert_link "$target_dir/config/local-only" "$dotfiles_dir/home/config/local-only"
			[[ ! -L "$dotfiles_dir/home/config/new-tracked" && ! -e "$dotfiles_dir/home/config/new-only" ]] \
				|| fail "Stow recovery introduced new overlays"
			cmp -s "$test_root/exclude.before" "$dotfiles_dir/.git/info/exclude" || fail "recovery changed excludes"
			[[ "$(git -C "$dotfiles_dir" ls-files -v home/config/tracked)" == S* ]] || fail "recovery lost skip bit"
			if [[ "$backend" == jj ]]; then
				[[ "$(jj -R "$dotfiles_dir" --ignore-working-copy sparse list)" == "$(<"$test_root/sparse.before")" ]] \
					|| fail "recovery changed sparse patterns"
			fi
			if [[ "$failure" == edit-fail ]]; then
				[[ "$(<"$dotfiles_dir/home/config/new-tracked")" == edited-during-stow ]] || fail "recovery erased base edit"
			fi
		done
	done

	new_fixture "$backend-no-active-overlays" "$backend"
	stow_test_mode=dry-fail
	if run_dotfiles >"$test_root/stow.out" 2>&1; then
		fail "Stow failure returned success"
	fi
	[[ ! -L "$dotfiles_dir/home/config/tracked" && ! -e "$dotfiles_dir/home/config/local-only" ]] \
		|| fail "recovery introduced overlays into a pure checkout"

	new_fixture "$backend-command-preflight" "$backend"
	run_overlay
	print -r -- new > "$overlay_dir/home/config/new-tracked"
	print -r -- dirty > "$dotfiles_dir/home/config/new-tracked"
	save_state
	if run_dotfiles >"$test_root/stow.out" 2>&1; then
		fail "dotfiles accepted a dirty new overlay destination"
	fi
	assert_state_unchanged
	assert_link "$dotfiles_dir/home/config/tracked" "$overlay_dir/home/config/tracked"
	[[ ! -e "$target_dir/stow.calls" ]] || fail "Stow ran before preflight refusal"

	new_fixture "$backend-scan-failure" "$backend"
	run_overlay
	save_state
	if DOTFILES_DIR="$dotfiles_dir" LOCAL_DOTFILES_DIR="$overlay_dir" zsh -c '
		fd() { return 1; }
		source "$1"
	' fixture "$repo_root/bin/dotfiles-install-overlay.zsh"; then
		fail "failed discovery was accepted"
	fi
	assert_state_unchanged
	assert_link "$dotfiles_dir/home/config/tracked" "$overlay_dir/home/config/tracked"

	new_fixture "$backend-parent-child" "$backend"
	mkdir -p "$target_dir/second-overlay/home/config/clash"
	print -r -- parent > "$overlay_dir/home/config/clash"
	print -r -- child > "$target_dir/second-overlay/home/config/clash/child"
	DOTFILES_OVERLAY_DIRS="$overlay_dir:$target_dir/second-overlay" assert_refused "parent collision:"
	[[ ! -e "$dotfiles_dir/home/config/clash" ]] || fail "conflicting desired parent was created"

	new_fixture "$backend-active-edit" "$backend"
	run_overlay
	stow_test_mode=active-edit-fail
	if run_dotfiles >"$test_root/stow.out" 2>&1; then
		fail "Stow failure returned success"
	fi
	[[ ! -L "$dotfiles_dir/home/config/tracked" && "$(<"$dotfiles_dir/home/config/tracked")" == edited-during-stow ]] \
		|| fail "recovery erased an edit to the formerly overlaid base"
	[[ "$(<"$test_root/stow.out")" == *"Could not restore previous overlays safely"* ]] \
		|| fail "unsafe recovery was not reported"

	new_fixture "$backend-command-success" "$backend"
	stow_test_mode=real
	run_dotfiles >"$test_root/stow.out" 2>&1 || fail "normal dotfiles failed: $(<"$test_root/stow.out")"
	assert_link "$target_dir/config/tracked" "$overlay_dir/home/config/tracked"
	run_dotfiles >"$test_root/stow.out" 2>&1 || fail "repeat dotfiles failed: $(<"$test_root/stow.out")"
	run_dotfiles --pure >"$test_root/stow.out" 2>&1 || fail "pure dotfiles failed: $(<"$test_root/stow.out")"
	[[ ! -L "$dotfiles_dir/home/config/tracked" && "$(<"$target_dir/config/tracked")" == base ]] || fail "pure mode lost base"
	[[ "$(readlink "$dotfiles_dir/home/config/base-link")" == new-tracked ]] || fail "pure mode lost tracked base symlink"
	[[ ! -e "$target_dir/config/local-only" && ! -L "$target_dir/config/local-only" ]] || fail "pure mode retained overlay-only home link"
done

print -r -- "dotfiles overlay tests passed"
