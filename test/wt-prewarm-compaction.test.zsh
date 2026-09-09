#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
test_root=${test_root:A}
trap 'rm -rf "$test_root"' EXIT

repository="$test_root/repository"
worktrees="$test_root/worktrees"
config="$test_root/worktrunk.toml"
prewarm_branch="worktrunk-prewarm-compaction-test"
prewarm_worktree="$worktrees/$prewarm_branch"

mkdir -p "$repository" "$worktrees"
git -C "$repository" init --initial-branch=main >/dev/null
git -C "$repository" config user.email "wt-prewarm@example.com"
git -C "$repository" config user.name "wt-prewarm test"
print -r -- "fixture" >"$repository/README.md"
print -r -- "committed on main" >"$repository/committed.txt"
print -r -- "clean on main" >"$repository/dirty.txt"
git -C "$repository" add README.md committed.txt dirty.txt
git -C "$repository" commit -m "Initial fixture" >/dev/null

cat >"$config" <<EOF
worktree-path = "$worktrees/{{ branch | sanitize }}"
EOF

export PATH="$repo_root/bin:$PATH"
export WORKTRUNK_CONFIG_PATH="$config"
export WT_PREWARM_BRANCH="$prewarm_branch"

ensure_output=$(
	cd "$repository"
	wt-prewarm ensure
)

if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: compacted prewarm was not marked ready"
	exit 1
fi

prewarm_git_dir=$(git -C "$prewarm_worktree" rev-parse --absolute-git-dir)
prewarm_receipt="$prewarm_git_dir/wt-prewarm-compaction"
if [[ "$(uname -s)" == "Darwin" && ! -f "$prewarm_receipt" ]]; then
	print -ru2 -- "FAIL: compacted prewarm did not record a receipt"
	exit 1
fi
[[ -f "$prewarm_receipt" ]] && prewarm_receipt_content=$(<"$prewarm_receipt")

if [[ "$(uname -s)" == "Darwin" ]]; then
	repository_device=$(stat -f %Sd "$repository" 2>/dev/null)
	if mount | grep -Eq "^/dev/${repository_device} on .+ \\(apfs[,)]" \
		&& [[ "$ensure_output" != *"wt-prewarm: compacted 3 tracked files against main"* ]]; then
		print -ru2 -- "FAIL: prewarm did not compact its tracked fixture on APFS"
		exit 1
	fi
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
	(
		cd "$repository"
		wt-prewarm prepare --create claimed >/dev/null
	)
	claimed_worktree="$worktrees/claimed"
	claimed_git_dir=$(git -C "$claimed_worktree" rev-parse --absolute-git-dir)
	if [[ ! -f "$claimed_git_dir/wt-prewarm-compaction" ]] \
		|| [[ "$(<"$claimed_git_dir/wt-prewarm-compaction")" != "$prewarm_receipt_content" ]]; then
		print -ru2 -- "FAIL: claimed prewarm did not retain its compaction receipt"
		exit 1
	fi

	claimed_status=$(
		cd "$repository"
		wt-prewarm compact-status claimed
	)
	if [[ "$claimed_status" != compacted:* ]]; then
		print -ru2 -- "FAIL: claimed worktree compaction receipt was not current"
		exit 1
	fi

	for _ in {1..100}; do
		[[ -f "$prewarm_worktree/.wt-prewarm-ready" ]] && break
		sleep 0.1
	done
fi

feature_worktree="$worktrees/feature"
git -C "$repository" worktree add -b feature "$feature_worktree" main >/dev/null
print -r -- "committed on feature" >"$feature_worktree/committed.txt"
git -C "$feature_worktree" add committed.txt
git -C "$feature_worktree" commit -m "Diverge feature" >/dev/null
print -r -- "dirty on feature" >"$feature_worktree/dirty.txt"

compact_output=$(
	cd "$repository"
	wt-prewarm compact feature
)

feature_status=$(
	cd "$repository"
	wt-prewarm compact-status feature
)
if [[ "$(uname -s)" == "Darwin" && "$feature_status" != compacted:* ]]; then
	print -ru2 -- "FAIL: existing worktree compaction receipt was not recorded"
	exit 1
fi

if [[ "$(<"$feature_worktree/committed.txt")" != "committed on feature" \
	|| "$(<"$feature_worktree/dirty.txt")" != "dirty on feature" ]]; then
	print -ru2 -- "FAIL: compact changed a divergent or dirty file"
	exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
	repository_device=$(stat -f %Sd "$repository" 2>/dev/null)
	if mount | grep -Eq "^/dev/${repository_device} on .+ \\(apfs[,)]" \
		&& [[ "$compact_output" != *"wt-prewarm: compacted 1 tracked files against main"* ]]; then
		print -ru2 -- "FAIL: existing worktree did not compact only matching files"
		exit 1
	fi
fi

(
	cd "$repository"
	wt-prewarm remove >/dev/null
)
print -r -- "locally modified" >"$repository/README.md"

dirty_output=$(
	cd "$repository"
	wt-prewarm ensure 2>&1
)

if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: prewarm with dirty main fallback was not marked ready"
	exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
	repository_device=$(stat -f %Sd "$repository" 2>/dev/null)
	if mount | grep -Eq "^/dev/${repository_device} on .+ \\(apfs[,)]" \
		&& [[ "$dirty_output" != *"wt-prewarm: skipping compaction; main worktree has tracked changes"* ]]; then
		print -ru2 -- "FAIL: dirty main worktree did not safely skip compaction"
		exit 1
	fi
fi

print -r -- "wt-prewarm compaction tests passed"
