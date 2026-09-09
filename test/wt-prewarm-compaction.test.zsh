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
git -C "$repository" add README.md
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

if [[ "$(uname -s)" == "Darwin" ]]; then
	repository_device=$(stat -f %Sd "$repository" 2>/dev/null)
	if mount | grep -Eq "^/dev/${repository_device} on .+ \\(apfs[,)]" \
		&& [[ "$ensure_output" != *"wt-prewarm: compacted 1 tracked files against main"* ]]; then
		print -ru2 -- "FAIL: prewarm did not compact its tracked fixture on APFS"
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
