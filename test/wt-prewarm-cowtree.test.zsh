#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
test_root=${test_root:A}
trap 'rm -rf "$test_root"' EXIT

repository="$test_root/repository"
worktrees="$test_root/worktrees"
mock_bin="$test_root/bin"
config="$test_root/worktrunk.toml"
invocation="$test_root/cowtree-invocation"
wt_invocations="$test_root/wt-invocations"
prewarm_branch="worktrunk-prewarm-cowtree-test"
prewarm_worktree="$worktrees/$prewarm_branch"

mkdir -p "$repository" "$worktrees" "$mock_bin"
git -C "$repository" init --initial-branch=main >/dev/null
git -C "$repository" config user.email "wt-prewarm@example.com"
git -C "$repository" config user.name "wt-prewarm test"
print -r -- "fixture" >"$repository/README.md"
git -C "$repository" add README.md
git -C "$repository" commit -m "Initial fixture" >/dev/null

cat >"$config" <<EOF
worktree-path = "$worktrees/{{ branch | sanitize }}"
EOF

cat >"$mock_bin/cowtree" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_COWTREE_INVOCATION"
[ "$1" = "add" ] || exit 2
shift
exec "$TEST_REAL_GIT" worktree add "$@"
EOF
chmod +x "$mock_bin/cowtree"

cat >"$mock_bin/wt" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$TEST_WT_INVOCATIONS"
exec "$TEST_REAL_WT" "$@"
EOF
chmod +x "$mock_bin/wt"

TEST_REAL_WT=$(command -v wt)
export TEST_REAL_WT
export PATH="$mock_bin:$repo_root/bin:$PATH"
export TEST_COWTREE_INVOCATION="$invocation"
export TEST_WT_INVOCATIONS="$wt_invocations"
TEST_REAL_GIT=$(command -v git)
export TEST_REAL_GIT
export WORKTRUNK_CONFIG_PATH="$config"
export WT_PREWARM_BRANCH="$prewarm_branch"

(
	cd "$repository"
	wt-prewarm ensure >/dev/null
)

if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: prewarm was not marked ready"
	exit 1
fi

if [[ ! -f "$invocation" ]] || ! grep -q '^add ' "$invocation"; then
	print -ru2 -- "FAIL: prewarm creation did not use cowtree add"
	exit 1
fi

(
	cd "$repository"
	wt-prewarm remove >/dev/null
)

if ! grep -q -- "^-y remove --foreground --force --force-delete --no-hooks ${prewarm_branch}$" \
	"$wt_invocations"; then
	print -ru2 -- "FAIL: prewarm removal did not use Worktrunk"
	exit 1
fi

if [[ -e "$prewarm_worktree" ]] || git -C "$repository" show-ref --verify --quiet \
	"refs/heads/$prewarm_branch"; then
	print -ru2 -- "FAIL: prewarm removal left its worktree or branch"
	exit 1
fi

print -r -- "wt-prewarm cowtree tests passed"
