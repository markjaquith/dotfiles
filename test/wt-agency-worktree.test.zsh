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
agency_worktree="$test_root/agency/tasks/example/code/repository"
second_worktree="$test_root/agency/tasks/second/code/repository"
config="$test_root/worktrunk.toml"
prewarm_prefix="worktree-prewarm-agency-"

mkdir -p "$repository" "$worktrees"
jj git init --colocate "$repository" >/dev/null
print -r -- "fixture" >"$repository/README.md"
(
	cd "$repository"
	jj commit -m "Initial fixture" >/dev/null
	jj bookmark create main -r @- >/dev/null
)

cat >"$config" <<EOF
worktree-path = "$worktrees/{{ branch | sanitize }}"

[list]
json-schema = 2
EOF

export PATH="$repo_root/bin:$PATH"
export WORKTRUNK_CONFIG_PATH="$config"
export WT_PREWARM_PREFIX="$prewarm_prefix"

(
	cd "$repository"
	wt-prewarm ensure --count 2 >/dev/null
)

prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne 2 ]]; then
	print -ru2 -- "FAIL: two prewarms were not ready before Agency-style creation"
	exit 1
fi

(
	cd "$repository"
	wt-new \
		--reuse-existing \
		--worktree-path "$agency_worktree" \
		--from main \
		agency-test >/dev/null
)

if [[ ! -d "$agency_worktree" ]]; then
	print -ru2 -- "FAIL: Agency-style creation did not use the requested path"
	exit 1
fi

if [[ -e "$agency_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: readiness marker leaked into the claimed worktree"
	exit 1
fi

if ! wt -C "$repository" list --format=json \
	| jq -e --arg path "$agency_worktree" \
		'.items[] | select(.branch == "agency-test" and .worktree.path == $path)' \
		>/dev/null; then
	print -ru2 -- "FAIL: Worktrunk did not register the Agency checkout path"
	exit 1
fi

# A remaining pool member means the default background `ensure` is a no-op.
sleep 0.5
prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne 1 ]]; then
	print -ru2 -- "FAIL: prewarm was replenished before the pool reached zero"
	exit 1
fi

# Claim the last member. This time background `ensure` must restore one.
(
	cd "$repository"
	wt-new \
		--reuse-existing \
		--worktree-path "$second_worktree" \
		--from main \
		agency-test-second >/dev/null
)

for _ in {1..100}; do
	prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
	[[ ${#prewarm_worktrees} -eq 1 && -f "${prewarm_worktrees[1]}/.wt-prewarm-ready" ]] && break
	sleep 0.1
done

if [[ ${#prewarm_worktrees} -ne 1 || ! -f "${prewarm_worktrees[1]}/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: prewarm was not replenished after the last claim"
	exit 1
fi

# Agency removes a checkout with `recycle --keep-branch` and later prepares it
# again at the same path. The existing branch must claim a pool member.
print -r -- "task work" >"$agency_worktree/task.txt"
git -C "$agency_worktree" add task.txt
git -C "$agency_worktree" -c user.email=wt@example.com -c user.name=wt \
	commit --quiet -m "Task work"
task_head=$(git -C "$agency_worktree" rev-parse HEAD)
(
	cd "$repository"
	wt-prewarm recycle --keep-branch --force "$agency_worktree" 2>/dev/null
)
[[ ! -e "$agency_worktree" ]] || {
	print -ru2 -- "FAIL: recycle did not remove the Agency checkout"
	exit 1
}

prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
pool_before=${#prewarm_worktrees}
reuse_log="$test_root/reuse.log"
(
	cd "$repository"
	wt-new \
		--reuse-existing \
		--worktree-path "$agency_worktree" \
		--from main \
		agency-test >/dev/null 2>"$reuse_log"
)

if ! grep -q "claimed prewarm → agency-test" "$reuse_log"; then
	print -ru2 -- "FAIL: reusing an existing branch did not claim a prewarm"
	cat "$reuse_log" >&2
	exit 1
fi
if [[ "$(git -C "$agency_worktree" symbolic-ref --short HEAD 2>/dev/null)" != "agency-test" \
	|| "$(git -C "$agency_worktree" rev-parse HEAD)" != "$task_head" ]]; then
	print -ru2 -- "FAIL: claimed checkout is not on the existing branch's commit"
	exit 1
fi
if [[ "$(<"$agency_worktree/task.txt")" != "task work" \
	|| -n "$(git -C "$agency_worktree" status --porcelain)" \
	|| -e "$agency_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: claimed checkout does not match the existing branch cleanly"
	exit 1
fi
if git -C "$repository" for-each-ref --format='%(refname:short)' "refs/heads/${prewarm_prefix}*" \
	| grep -qvx -f <(git -C "$repository" worktree list --porcelain \
		| sed -n "s|^branch refs/heads/||p"); then
	print -ru2 -- "FAIL: claiming an existing branch left an orphaned prewarm branch"
	exit 1
fi
prewarm_worktrees=("$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N))
if [[ ${#prewarm_worktrees} -ne $(( pool_before - 1 )) ]]; then
	print -ru2 -- "FAIL: claiming an existing branch did not consume one pool member"
	exit 1
fi

# An existing branch that is already checked out is switched to, not claimed.
(
	cd "$repository"
	wt-new --reuse-existing --worktree-path "$second_worktree" agency-test-second \
		>/dev/null 2>"$reuse_log"
) || {
	print -ru2 -- "FAIL: reusing a checked-out branch failed"
	exit 1
}
if grep -q "claimed prewarm" "$reuse_log"; then
	print -ru2 -- "FAIL: reusing a checked-out branch claimed a prewarm"
	exit 1
fi

# `prepare --create` still refuses a branch that already exists.
git -C "$repository" branch agency-existing-unchecked main
if (cd "$repository" && wt-prewarm prepare --create agency-existing-unchecked >/dev/null 2>&1); then
	print -ru2 -- "FAIL: prepare --create accepted an existing branch"
	exit 1
fi

print -r -- "wt Agency worktree test passed"
