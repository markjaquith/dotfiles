#!/usr/bin/env zsh

set -eu
setopt pipefail

repo_root=${0:A:h:h}
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
temp_dir=${temp_dir:A}
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
typeset -i test_count=0

fail() {
	print -u2 -- "FAIL: $*"
	print -u2 -- "stage=${FAIL_STAGE:-}, command=${FAIL_COMMAND:-}"
	print -u2 -r -- "${output:-}"
	exit 1
}

assert_contains() {
	(( ++test_count ))
	[[ "$1" == *"$2"* ]] || fail "missing: $2"
}

assert_absent() {
	(( ++test_count ))
	[[ "$1" != *"$2"* ]] || fail "unexpected: $2"
}

assert_status() {
	(( ++test_count ))
	[[ "$result" == "$1" ]] || fail "expected exit $1, got $result"
}

# Only the driver and selected audited sources are copied. All executables
# reachable through the fixture PATH are stubs or explicit read-only utilities.
fixture="$temp_dir/fixture with spaces"
mkdir -p "$fixture/home/dotfiles/bin" "$fixture/commands" \
	"$fixture/home/.local-dotfiles/bin" "$fixture/home/Library/Fonts" \
	"$fixture/home/Library/Application Support/lazygit"
cp "$repo_root/bin/dotfiles-install" "$fixture/home/dotfiles/bin/"
ln -s /bin/zsh "$fixture/commands/zsh"
ln -s /bin/cat "$fixture/commands/cat"
ln -s /usr/bin/dirname "$fixture/commands/dirname"

print -r -- '#!/bin/zsh -f
name=${0:t}
print -r -- "command:$name:$*" >> "$EVENTS"
if [[ "$name" == "$FAIL_COMMAND" ]]; then
	print -u2 -- "stub $name failed"
	return 23
fi
if [[ "$name" == git && "$3" == --unset-all ]]; then
	key=$4
	[[ "$key" == --fixed-value ]] && key=$5
	if [[ -z "$CONFIG_UNSET_KEY" || "$key" == "$CONFIG_UNSET_KEY" ]]; then
		return "$CONFIG_UNSET_STATUS"
	fi
	return 5
fi
if [[ "$name" == sed ]]; then
	exec /usr/bin/sed "$@"
fi
# Exercise filesystem behavior, but only for the exact fixture symlink paths.
if [[ "$name" == rm ]]; then
	[[ $# == 2 && "$1" == -f &&
		"$2" == "$HOME/Library/Application Support/lazygit/config.yml" ]] || exit 95
	exec /bin/rm "$@"
fi
if [[ "$name" == ln ]]; then
	[[ $# == 3 && "$1" == -s && "$2" == "$HOME/.config/lazygit/config.yml" &&
		"$3" == "$HOME/Library/Application Support/lazygit/config.yml" ]] || exit 95
	exec /bin/ln "$@"
fi
if [[ "$name" == bun ]]; then
	[[ "$PWD" == "$HOME/dotfiles" ]] || exit 91
	[[ "$LOCAL_CONTEXT" == retained ]] || exit 92
fi
if [[ "$name" == mise || "$name" == hk ||
	( "$name" == git && "$*" == "config core.hooksPath .git/hooks" ) ]]; then
	[[ "$PWD" == "$HOME/dotfiles" ]] || exit 94
fi
if [[ "$name" == pip && -n "$PIP_OUTPUT" ]]; then
	print -r -- "$PIP_OUTPUT"
fi
exit 0' > "$fixture/commands/stub"
chmod +x "$fixture/commands/stub"
for name in bun git mise hk pip uv sed ln rm mkdir; do
	ln -s stub "$fixture/commands/$name"
done
cp "$fixture/commands/stub" "$fixture/home/dotfiles/bin/crontab-sync"

print -r -- '
fixture_stage() {
	local name=$1
	print -r -- "start:$name" >> "$EVENTS"
	print -r -- started > "$FIXTURE/$name.started"
	if [[ "$PARALLEL_PROBE" == yes ]]; then
		local peer=""
		case "$name" in
			brew) peer=bun ;;
			bun) peer=brew ;;
			mise) peer=tools ;;
			tools) peer=mise ;;
		esac
		if [[ -n "$peer" ]]; then
			zmodload zsh/zselect
			local attempts=0
			until [[ -f "$FIXTURE/$peer.started" ]]; do
				(( ++attempts <= 100 )) || return 90
				zselect -t 5 || true
			done
		fi
		if [[ "$name" == mise ]]; then
			zselect -t 20 || true
		fi
	fi
	case "$name" in
		configs|fonts|local|git-hooks)
			[[ -f "$FIXTURE/mise.done" ]] || return 93
			;;
	esac
	if [[ "$name" == "$FAIL_STAGE" || "$name" == "$FAIL_STAGE_2" ]]; then
		return 23
	fi
	print -r -- "done:$name" >> "$EVENTS"
	print -r -- done > "$FIXTURE/$name.done"
}
' > "$fixture/stages.zsh"

reset_fixture() {
	local name
	rm -f "$fixture/"*.started(N) "$fixture/"*.done(N)
	rm -rf "$fixture/home/Library/Application Support/lazygit/config.yml"
	: > "$fixture/events"
	for name in prereqs brew bun pip mise tools configs fonts git-hooks; do
		print -r -- "source \"\$FIXTURE/stages.zsh\"
fixture_stage $name
print -r -- tail:$name >> \"\$EVENTS\"" \
			> "$fixture/home/dotfiles/bin/dotfiles-install-$name.zsh"
	done
	print -r -- '
DOTFILES_DIR="$HOME/dotfiles"
LOCAL_DOTFILES_DIR="$HOME/.local-dotfiles"
export HOMEBREW_NO_AUTO_UPDATE=1
prereq_context=retained
' >> "$fixture/home/dotfiles/bin/dotfiles-install-prereqs.zsh"
	print -r -- '
cd "$HOME/Library/Fonts"
' >> "$fixture/home/dotfiles/bin/dotfiles-install-fonts.zsh"
	print -r -- '
source "$FIXTURE/stages.zsh"
fixture_stage local
[[ "$SCRIPT_DIR" == "$HOME/dotfiles/bin" ]]
[[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]]
[[ "$LOCAL_DOTFILES_DIR" == "$HOME/.local-dotfiles" ]]
[[ "$HOMEBREW_NO_AUTO_UPDATE" == 1 && "$prereq_context" == retained ]]
cd "$HOME/Library/Fonts"
export LOCAL_CONTEXT=retained
bun() {
	print -r -- local-bun-function >> "$EVENTS"
	command bun "$@"
}
print -r -- tail:local >> "$EVENTS"
' > "$fixture/home/.local-dotfiles/bin/dotfiles-install"
	export FAIL_STAGE="" FAIL_STAGE_2="" FAIL_COMMAND="" PARALLEL_PROBE=no
	export CONFIG_UNSET_STATUS=5 CONFIG_UNSET_KEY="" PIP_OUTPUT="" LOCAL_CONTEXT=""
}

run_driver() {
	result=0
	# A file, not command substitution: inherited output pipes would themselves
	# wait for orphaned children and conceal a missing wait in the driver.
	HOME="$fixture/home" PATH="$fixture/commands" \
		FIXTURE="$fixture" EVENTS="$fixture/events" \
		/bin/zsh -f "$fixture/home/dotfiles/bin/dotfiles-install" "$@" \
		> "$fixture/output" 2>&1 || result=$?
	output=$(<"$fixture/output")
	events=$(<"$fixture/events")
}

reset_fixture
run_driver --help
assert_status 0
assert_contains "$output" Usage:
assert_absent "$events" start:
run_driver --unknown
assert_status 64
assert_absent "$events" start:

reset_fixture
export PARALLEL_PROBE=yes
run_driver
assert_status 0
assert_contains "$output" 'Done!'
assert_contains "$events" 'tail:git-hooks'
assert_contains "$events" 'local-bun-function'
assert_contains "$events" 'command:bun:i'
assert_contains "$events" $'done:mise\ntail:mise\nstart:configs'

reset_fixture
rm "$fixture/home/.local-dotfiles/bin/dotfiles-install"
export LOCAL_CONTEXT=retained
run_driver
assert_status 0
assert_absent "$events" start:local
assert_contains "$events" command:bun:i

reset_fixture
rm "$fixture/commands/bun"
run_driver
assert_status 127
assert_contains "$output" 'dependencies failed (exit 127)'
assert_absent "$output" 'Done!'
ln -s stub "$fixture/commands/bun"

# Fail before a successful tail in every sourced stage. This catches accidental
# conditional invocation, which silently disables errexit in sourced functions.
for name in prereqs brew bun pip mise tools configs fonts local git-hooks; do
	reset_fixture
	export FAIL_STAGE=$name
	run_driver
	(( ++test_count ))
	(( result != 0 )) || fail "$name failure was masked"
	assert_contains "$output" "$name failed (exit 23)"
	assert_absent "$output" 'Done!'
	assert_absent "$events" "tail:$name"
	case "$name" in
		prereqs) assert_absent "$events" start:brew ;;
		brew) assert_contains "$events" tail:bun ;;
		bun) assert_contains "$events" tail:brew ;;
		mise|tools) assert_absent "$events" start:configs ;;
	esac
done

for name in prereqs brew pip local; do
	reset_fixture
	if [[ "$name" == local ]]; then
		stage_file="$fixture/home/.local-dotfiles/bin/dotfiles-install"
	else
		stage_file="$fixture/home/dotfiles/bin/dotfiles-install-$name.zsh"
	fi
	print -r -- 'exit 37' > "$stage_file"
	run_driver
	(( ++test_count ))
	(( result != 0 )) || fail "$name explicit exit was masked"
	assert_contains "$output" 'installation failed (exit '
	assert_absent "$output" 'Done!'
done

reset_fixture
export FAIL_STAGE=brew FAIL_STAGE_2=bun
run_driver
assert_status 1
assert_contains "$output" 'brew=23, bun=23'

reset_fixture
export FAIL_STAGE=tools PARALLEL_PROBE=yes
run_driver
assert_status 1
assert_contains "$events" tail:mise
assert_contains "$output" 'mise=0, tools=23'
assert_absent "$events" start:configs

reset_fixture
export FAIL_STAGE=mise FAIL_STAGE_2=tools
run_driver
assert_status 1
assert_contains "$output" 'mise=23, tools=23'

for name in crontab-sync bun; do
	reset_fixture
	export FAIL_COMMAND=$name
	run_driver
	assert_status 23
	assert_contains "$output" "stub $name failed"
	assert_absent "$output" 'Done!'
	assert_absent "$events" start:git-hooks
done

# Exercise real pip source with stub pip/uv and read-only sed: an empty filter
# is OK, but pipefail must still retain a failing upstream pip command.
for mode in empty filtered visible mixed pip-failure filter-failure uv-failure; do
	reset_fixture
	cp "$repo_root/bin/dotfiles-install-pip.zsh" "$fixture/home/dotfiles/bin/"
	case "$mode" in
		filtered) export PIP_OUTPUT=DEPRECATION ;;
		visible) export PIP_OUTPUT=installed ;;
		mixed) export PIP_OUTPUT=$'installed\nDEPRECATION warning' ;;
		pip-failure) export FAIL_COMMAND=pip ;;
		filter-failure) export FAIL_COMMAND=sed ;;
		uv-failure) export FAIL_COMMAND=uv ;;
	esac
	run_driver
	if [[ "$mode" == *-failure ]]; then
		assert_status 23
		assert_contains "$output" 'pip failed (exit 23)'
		assert_absent "$events" start:mise
		assert_absent "$output" 'Done!'
		if [[ "$mode" != uv-failure ]]; then
			assert_absent "$events" command:uv:
		fi
	else
		assert_status 0
		assert_contains "$events" 'command:uv:tool install jrnl'
		assert_absent "$output" DEPRECATION
		if [[ "$mode" == visible || "$mode" == mixed ]]; then
			assert_contains "$output" installed
		fi
	fi
done

# Config cleanup may find nothing to remove, but real command failures are not
# optional. All config mutations below resolve to fixture-only command stubs.
config_target="$fixture/home/Library/Application Support/lazygit/config.yml"
for mode in absent existing-file dangling-link directory write-failure remove-failure link-failure mkdir-failure; do
	reset_fixture
	cp "$repo_root/bin/dotfiles-install-configs.zsh" "$fixture/home/dotfiles/bin/"
	case "$mode" in
		existing-file) print -r -- old-config > "$config_target" ;;
		dangling-link) ln -s missing-target "$config_target" ;;
		directory) mkdir "$config_target" ;;
		write-failure) export FAIL_COMMAND=git ;;
		remove-failure) export FAIL_COMMAND=rm ;;
		link-failure) export FAIL_COMMAND=ln ;;
		mkdir-failure) export FAIL_COMMAND=mkdir ;;
	esac
	run_driver
	case "$mode" in
		absent|existing-file|dangling-link)
			assert_status 0
			(( ++test_count ))
			[[ -L "$config_target" && "$(readlink "$config_target")" == "$fixture/home/.config/lazygit/config.yml" ]] ||
				fail "config symlink was not installed"
			assert_contains "$events" 'command:git:config --global --unset-all pager.diff'
			assert_contains "$events" 'command:git:config --global --unset-all pager.show'
			assert_contains "$events" 'command:git:config --global --unset-all pager.log'
			assert_contains "$events" 'command:git:config --global --unset-all --fixed-value include.path ~/.config/delta/themes/catppuccin-macchiato'
			# A second run must also work when the target symlink already exists.
			run_driver
			assert_status 0
			;;
		directory)
			assert_status 1
			assert_absent "$events" command:ln:
			;;
		*) assert_status 23 ;;
	esac
	if [[ "$mode" != absent && "$mode" != existing-file && "$mode" != dangling-link ]]; then
		assert_contains "$output" 'configs failed'
		assert_absent "$output" 'Done!'
		assert_absent "$events" command:crontab-sync:
	fi
done

# Successful unsets and absent values are OK; every other status must survive,
# including failures after an earlier cleanup succeeded or found nothing.
for key in pager.diff pager.show pager.log include.path; do
	for unset_status in 0 1 2 3 4 6 128; do
		reset_fixture
		cp "$repo_root/bin/dotfiles-install-configs.zsh" "$fixture/home/dotfiles/bin/"
		export CONFIG_UNSET_KEY=$key CONFIG_UNSET_STATUS=$unset_status
		run_driver
		assert_status "$unset_status"
		if (( unset_status )); then
			assert_contains "$output" "configs failed (exit $unset_status)"
			assert_absent "$events" 'command:git:config --global alias.fixup'
			assert_absent "$output" 'Done!'
		else
			assert_contains "$events" 'command:git:config --global alias.fixup'
		fi
	done
done

# Hook setup uses the repository cwd, and never runs later commands after an
# earlier failure. It must report errors rather than hiding stderr.
for name in none git mise hk; do
	reset_fixture
	cp "$repo_root/bin/dotfiles-install-git-hooks.zsh" "$fixture/home/dotfiles/bin/"
	export FAIL_COMMAND=$name
	run_driver
	if [[ "$name" == none ]]; then
		assert_status 0
		assert_contains "$events" 'command:hk:install'
	else
		assert_status 23
		assert_contains "$output" "stub $name failed"
		assert_contains "$output" 'git-hooks failed (exit 23)'
		assert_absent "$output" 'Done!'
	fi
	case "$name" in
		git) assert_absent "$events" command:mise: ;;
		mise) assert_absent "$events" command:hk: ;;
	esac
done

print -r -- "$test_count dotfiles-install assertions passed (stub-only fixtures)"
