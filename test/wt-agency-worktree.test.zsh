#!/usr/bin/env zsh
set -eo pipefail

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

print -r -- "wt Agency worktree test passed"
