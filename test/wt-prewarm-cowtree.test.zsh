#!/usr/bin/env zsh
set -eo pipefail

# Git hooks export repository variables such as GIT_INDEX_FILE; clear them so
# fixture repositories are not redirected to the calling repository.
unset $(git rev-parse --local-env-vars)

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
prewarm_prefix="worktree-prewarm-cow-"

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
printf '%s\n' "$*" >>"$TEST_COWTREE_INVOCATION"
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
export WT_PREWARM_PREFIX="$prewarm_prefix"

(
	cd "$repository"
	wt-prewarm ensure --count 3 >/dev/null
)

prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne 3 ]]; then
	print -ru2 -- "FAIL: ensure --count 3 did not create three prewarms"
	exit 1
fi

for prewarm_worktree in "${prewarm_worktrees[@]}"; do
	if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
		print -ru2 -- "FAIL: prewarm was not marked ready: $prewarm_worktree"
		exit 1
	fi
done

if [[ ! -f "$invocation" ]] || [[ $(grep -c '^add ' "$invocation") -ne 3 ]]; then
	print -ru2 -- "FAIL: prewarm creation did not use cowtree add three times"
	exit 1
fi

# A lower minimum does not shrink or build, while refresh rebuilds every member
# and preserves the larger existing pool size.
(
	cd "$repository"
	wt-prewarm ensure --count 2 >/dev/null
	wt-prewarm ensure --count 2 --refresh >/dev/null
)

if [[ $(grep -c '^add ' "$invocation") -ne 6 ]]; then
	print -ru2 -- "FAIL: refresh did not rebuild all three existing prewarms"
	exit 1
fi

prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne 3 ]]; then
	print -ru2 -- "FAIL: refresh unexpectedly changed the larger pool size"
	exit 1
fi

# Two claims reserve different members rather than contending on one pool-wide
# claim lock. The third member prevents either background ensure from building.
(
	cd "$repository"
	wt-prewarm prepare --create claim-one >/dev/null
) &
claim_one_pid=$!
(
	cd "$repository"
	wt-prewarm prepare --create claim-two >/dev/null
) &
claim_two_pid=$!
wait "$claim_one_pid"
wait "$claim_two_pid"

if [[ ! -d "$worktrees/claim-one" || ! -d "$worktrees/claim-two" ]]; then
	print -ru2 -- "FAIL: concurrent claims did not claim distinct pool members"
	exit 1
fi
sleep 0.5
prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne 1 ]] || [[ $(grep -c '^add ' "$invocation") -ne 6 ]]; then
	print -ru2 -- "FAIL: concurrent claims replenished a nonempty pool"
	exit 1
fi

# Ensure also cleans up the legacy singleton automatically.
git -C "$repository" worktree add -b worktrunk-prewarm \
	"$worktrees/worktrunk-prewarm" main >/dev/null
(
	cd "$repository"
	wt-prewarm ensure --count 2 >/dev/null
)
if git -C "$repository" show-ref --verify --quiet refs/heads/worktrunk-prewarm; then
	print -ru2 -- "FAIL: ensure did not remove the legacy prewarm"
	exit 1
fi

status_output=$(
	cd "$repository"
	wt-prewarm status
)
if [[ "$status_output" != ready:\ 2,\ building:\ 0,\ total:\ 2* ]]; then
	print -ru2 -- "FAIL: status did not summarize and list the pool"
	exit 1
fi

if (cd "$repository" && wt-prewarm ensure --count nope >/dev/null 2>&1); then
	print -ru2 -- "FAIL: ensure accepted an invalid count"
	exit 1
fi
if (cd "$repository" && wt-prewarm rebuild >/dev/null 2>&1); then
	print -ru2 -- "FAIL: removed rebuild command still succeeded"
	exit 1
fi

(
	cd "$repository"
	wt-prewarm remove >/dev/null
)

if [[ $(grep -c -- "^-y remove --foreground --force --force-delete --no-hooks ${prewarm_prefix}" \
	"$wt_invocations") -lt 5 ]]; then
	print -ru2 -- "FAIL: pool removal did not use Worktrunk for each member"
	exit 1
fi

if [[ -n "$(git -C "$repository" for-each-ref \
	--format='%(refname:short)' "refs/heads/${prewarm_prefix}*")" ]]; then
	print -ru2 -- "FAIL: prewarm removal left pool branches"
	exit 1
fi
prewarm_worktrees=("$worktrees"/${prewarm_prefix}*(N))
if [[ ${#prewarm_worktrees} -ne 0 ]]; then
	print -ru2 -- "FAIL: prewarm removal left pool worktrees"
	exit 1
fi

print -r -- "wt-prewarm cowtree tests passed"
