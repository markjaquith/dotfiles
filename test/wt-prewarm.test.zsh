#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mock_bin="$test_root/bin"
common_dir="$test_root/git-common"
active_dir="$test_root/wt-active"
overlap_file="$test_root/wt-overlap"
directive_leak_file="$test_root/directive-leak"
mkdir -p "$mock_bin" "$common_dir"

cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env zsh

case "$1:$2" in
	rev-parse:--is-inside-work-tree)
		exit 0
		;;
	rev-parse:--git-common-dir)
		print -r -- "$TEST_COMMON_DIR"
		exit 0
		;;
	show-ref:--verify)
		exit 1
		;;
	worktree:list)
		exit 0
		;;
esac

print -ru2 -- "unexpected git invocation: $*"
exit 1
EOF

cat >"$mock_bin/wt" <<'EOF'
#!/usr/bin/env zsh

if [[ -n "${WORKTRUNK_DIRECTIVE_CD_FILE:-}" \
	|| -n "${WORKTRUNK_DIRECTIVE_EXEC_FILE:-}" \
	|| -n "${WORKTRUNK_DIRECTIVE_FILE:-}" ]]; then
	touch "$TEST_DIRECTIVE_LEAK_FILE"
fi

if ! mkdir "$TEST_ACTIVE_DIR" 2>/dev/null; then
	touch "$TEST_OVERLAP_FILE"
	exit 1
fi

sleep 0.1
rmdir "$TEST_ACTIVE_DIR"
EOF

chmod +x "$mock_bin/git" "$mock_bin/wt"

export PATH="$mock_bin:$PATH"
export TEST_COMMON_DIR="$common_dir"
export TEST_ACTIVE_DIR="$active_dir"
export TEST_OVERLAP_FILE="$overlap_file"
export TEST_DIRECTIVE_LEAK_FILE="$directive_leak_file"
export WORKTRUNK_DIRECTIVE_CD_FILE="$test_root/cd-directive"
export WORKTRUNK_DIRECTIVE_EXEC_FILE="$test_root/exec-directive"
export WORKTRUNK_DIRECTIVE_FILE="$test_root/legacy-directive"

typeset -a pids
for i in {1..5}; do
	"$repo_root/bin/wt-prewarm" prepare --create "test-$i" &
	pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done

if (( failed )); then
	print -ru2 -- "FAIL: concurrent prepare command failed"
	exit 1
fi

if [[ -e "$overlap_file" ]]; then
	print -ru2 -- "FAIL: checkout-producing wt calls overlapped"
	exit 1
fi

if [[ -e "$directive_leak_file" ]]; then
	print -ru2 -- "FAIL: internal wt call inherited shell directive files"
	exit 1
fi

print -r -- "wt-prewarm tests passed"
