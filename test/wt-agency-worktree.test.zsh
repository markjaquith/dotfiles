#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
test_root=${test_root:A}
trap 'rm -rf "$test_root"' EXIT

repository="$test_root/repository"
worktrees="$test_root/worktrees"
agency_worktree="$test_root/agency/tasks/example/code/repository"
config="$test_root/worktrunk.toml"
prewarm_branch="worktrunk-prewarm-agency-test"
prewarm_worktree="$worktrees/$prewarm_branch"

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
export WT_PREWARM_BRANCH="$prewarm_branch"

(
	cd "$repository"
	wt-prewarm ensure >/dev/null
)

if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: prewarm was not ready before Agency-style creation"
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

for _ in {1..100}; do
	[[ -f "$prewarm_worktree/.wt-prewarm-ready" ]] && break
	sleep 0.1
done

if [[ ! -f "$prewarm_worktree/.wt-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: prewarm was not replenished after the claim"
	exit 1
fi

print -r -- "wt Agency worktree test passed"
