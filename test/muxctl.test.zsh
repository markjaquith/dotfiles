#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
muxctl=$repo_root/bin/muxctl
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/muxctl-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

typeset -i test_count=0
log=$tmp_dir/log

for name in herdr rex; do
	cat >"$tmp_dir/$name" <<MOCK
#!/usr/bin/env zsh
print -r -- "$name \$*" >>"$log"
if [[ "\$*" == '--autostart=false block inspect '* ]]; then
	print -r -- '{"block":{"block_id":"block:b1","window_id":"window:w7"}}'
fi
MOCK
	chmod +x "$tmp_dir/$name"
done

run() {
	: >"$log"
	env -i PATH="$PATH" MUXCTL_HERDR_BIN="$tmp_dir/herdr" \
		MUXCTL_REX_BIN="$tmp_dir/rex" "$@"
}

expect_log() {
	local name=$1 expected=$2 actual
	actual=$(<"$log")
	(( ++test_count ))
	if [[ $actual != $expected ]]; then
		print -ru2 -- "FAIL: $name"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		exit 1
	fi
}

expect_failure() {
	local name=$1
	shift
	(( ++test_count ))
	if run "$@" 2>/dev/null; then
		print -ru2 -- "FAIL: $name succeeded"
		exit 1
	fi
	[[ ! -s $log ]] || { print -ru2 -- "FAIL: $name ran $(<"$log")"; exit 1 }
}

herdr_env=(HERDR_ENV=1 HERDR_TAB_ID=w1:t2 HERDR_WORKSPACE_ID=w1)
rex_env=(REX_SESSION=session:s1 REX_BLOCK=block:b1)

[[ $(run "${herdr_env[@]}" "$muxctl" which) == herdr ]]
[[ $(run "${rex_env[@]}" "$muxctl" which) == rex ]]
[[ $(run "${herdr_env[@]}" "${rex_env[@]}" "$muxctl" which) == herdr ]]
[[ $(run "${herdr_env[@]}" "${rex_env[@]}" "$muxctl" --mux rex which) == rex ]]
[[ $(run "$muxctl" which || true) == none ]]
(( test_count += 5 ))

run "${herdr_env[@]}" "$muxctl" tab rename-self ' ABC-1'
expect_log 'herdr rename' 'herdr tab rename w1:t2  ABC-1'
run "${herdr_env[@]}" "$muxctl" tab close-self
expect_log 'herdr close' 'herdr tab close w1:t2'
run "${herdr_env[@]}" "$muxctl" workspace rename 'My work'
expect_log 'herdr workspace' 'herdr workspace rename w1 My work'

run "${rex_env[@]}" "$muxctl" tab rename-self ' ABC-1'
expect_log 'rex rename' $'rex --autostart=false block inspect -s session:s1 block:b1 --json\nrex --autostart=false window rename -s session:s1 window:w7  ABC-1'
run "${rex_env[@]}" "$muxctl" tab close-self
expect_log 'rex close' $'rex --autostart=false block inspect -s session:s1 block:b1 --json\nrex --autostart=false window close -s session:s1 window:w7'
run "${rex_env[@]}" "$muxctl" workspace rename 'My work'
expect_log 'rex workspace' 'rex --autostart=false session rename session:s1 My work'

expect_failure 'outside any mux' "$muxctl" tab close-self
expect_failure 'herdr without tab id' HERDR_ENV=1 "$muxctl" tab close-self
expect_failure 'rex without block' REX_SESSION=session:s1 "$muxctl" tab close-self
expect_failure 'bad mux' "${rex_env[@]}" "$muxctl" --mux tmux which
expect_failure 'missing label' "${rex_env[@]}" "$muxctl" tab rename-self
expect_failure 'unknown command' "${rex_env[@]}" "$muxctl" tab open

print -r -- "$test_count muxctl tests passed"
