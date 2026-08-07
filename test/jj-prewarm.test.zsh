#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

main="$test_root/main"
workspaces="$test_root/workspaces"
prewarm_pool="$test_root/prewarm-pool"
prewarm="$prewarm_pool/prewarm"
feature="$workspaces/feature-one"
export JJ_PREWARM_ROOT="$prewarm_pool"
export JJ_PREWARM_WORKSPACES_ROOT="$workspaces"

jj git init "$main" >/dev/null
mkdir -p "$main/cache"
print -r -- "cache/" >"$main/.gitignore"
print -r -- "base" >"$main/tracked.txt"
jj -R "$main" commit -m "base" >/dev/null
jj -R "$main" bookmark create main -r @- >/dev/null

(
	cd "$main"
	"$repo_root/bin/jj-prewarm" ensure --revision main --path "$prewarm" >/dev/null
)

mkdir -p "$prewarm/cache"
print -r -- "already installed" >"$prewarm/cache/dependency"

result=$(
	cd "$main"
	JJ_PREWARM_NO_REPLENISH=1 \
		"$repo_root/bin/jj-prewarm" prepare --revision main --path "$feature" feature-one
)

if [[ "${result:A}" != "${feature:A}" ]]; then
	print -ru2 -- "FAIL: prepare returned ${result}, expected ${feature}"
	exit 1
fi

if [[ ! -d "$feature" || -L "$feature" ]]; then
	print -ru2 -- "FAIL: adopted workspace is not a real directory"
	exit 1
fi

if [[ -e "$prewarm" ]]; then
	print -ru2 -- "FAIL: old prewarm path remains after adoption"
	exit 1
fi

if [[ ! -f "$feature/cache/dependency" ]]; then
	print -ru2 -- "FAIL: ignored prewarm artifact did not survive adoption"
	exit 1
fi

resolved=$(jj -R "$main" workspace root --name feature-one)
if [[ "${resolved:A}" != "${feature:A}" ]]; then
	print -ru2 -- "FAIL: workspace metadata resolves to ${resolved}"
	exit 1
fi

if [[ -n "$(jj -R "$feature" diff --summary)" ]]; then
	print -ru2 -- "FAIL: adopted workspace commit is not empty"
	exit 1
fi

if [[ -e "$feature/.jj-prewarm-ready" ]]; then
	print -ru2 -- "FAIL: readiness marker leaked into adopted workspace"
	exit 1
fi

if [[ -e "$main/.jj/repo/jj-prewarm-state" ]]; then
	print -ru2 -- "FAIL: adopted workspace retained prewarm ownership state"
	exit 1
fi

(
	cd "$main"
	"$repo_root/bin/jj-prewarm" ensure --revision main --path "$prewarm" >/dev/null
)

if [[ ! -d "$prewarm" ]]; then
	print -ru2 -- "FAIL: ensure did not replenish the prewarm workspace"
	exit 1
fi

IFS= read -r owned_prewarm <"$main/.jj/repo/jj-prewarm-state"
if [[ "$owned_prewarm" != "${prewarm:A}" ]]; then
	print -ru2 -- "FAIL: replenished prewarm ownership state is incorrect"
	exit 1
fi

(
	cd "$main"
	"$repo_root/bin/jj-prewarm" rebuild --revision main --path "$prewarm" >/dev/null
)

quarantine="$workspaces/prewarm.removing.interrupted"
print -rl -- "$prewarm" "$quarantine" >"$main/.jj/repo/jj-prewarm-remove-journal"
mv "$prewarm" "$quarantine"
(
	cd "$main"
	"$repo_root/bin/jj-prewarm" ensure --revision main --path "$prewarm" >/dev/null
)
if [[ ! -d "$prewarm" || -e "$quarantine" ]]; then
	print -ru2 -- "FAIL: interrupted removal was not recovered"
	exit 1
fi
stale_ownership="$test_root/stale-prewarm-state"
cp "$main/.jj/repo/jj-prewarm-state" "$stale_ownership"

typeset -a pids
for name in concurrent-one concurrent-two; do
	(
		cd "$main"
		JJ_PREWARM_NO_REPLENISH=1 \
			"$repo_root/bin/jj-prewarm" prepare --revision main "$name" >/dev/null
	) &
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

for name in concurrent-one concurrent-two; do
	resolved=$(jj -R "$main" workspace root --name "$name")
	if [[ "${resolved:A}" != "${workspaces:A}/${name}" ]]; then
		print -ru2 -- "FAIL: concurrent workspace ${name} resolves to ${resolved}"
		exit 1
	fi
done

adoption_lock="$main/.jj/repo/jj-prewarm.lock"
mkdir "$adoption_lock"
print -r -- "$$" >"$adoption_lock/owner"
touch -t 200001010000 "$adoption_lock"
(
	cd "$main"
	"$repo_root/bin/jj-prewarm" remove >/dev/null
) &
waiter_pid=$!
sleep 0.3
if ! kill -0 "$waiter_pid" 2>/dev/null; then
	print -ru2 -- "FAIL: a live old adoption lock was stolen"
	exit 1
fi
rm -f "$adoption_lock/owner"
rmdir "$adoption_lock"
wait "$waiter_pid"

mkdir "$adoption_lock"
print -r -- "999999" >"$adoption_lock/owner"
touch "$adoption_lock.reap"
(
	cd "$main"
	"$repo_root/bin/jj-prewarm" remove >/dev/null
)
if [[ -d "$adoption_lock" ]]; then
	print -ru2 -- "FAIL: dead adoption lock was not reaped"
	exit 1
fi

rm -f "$adoption_lock.reap"
mkdir "$adoption_lock.reap"
touch -t 200001010000 "$adoption_lock.reap"
mkdir "$adoption_lock"
print -r -- "999999" >"$adoption_lock/owner"
(
	cd "$main"
	"$repo_root/bin/jj-prewarm" remove >/dev/null
)
if [[ -d "$adoption_lock.reap" || -d "$adoption_lock" ]]; then
	print -ru2 -- "FAIL: legacy orphaned reaper directory was not recovered"
	exit 1
fi

repo_store="${main:A}/.jj/repo"
index_fixture="$test_root/workspace-index"
expected_index="$test_root/workspace-index.expected"
concurrent_root=$(jj -R "$main" workspace root --name concurrent-one)
metadata_target="${concurrent_root:h}/metadata-target"
cp "$repo_store/workspace_store/index" "$index_fixture"
printf '\x38\x2a' >>"$index_fixture"
cp "$index_fixture" "$expected_index"

flock "$index_fixture.lock" bun "$repo_root/bin/jj-workspace-store-path.ts" \
	"$index_fixture" "$repo_store" concurrent-one \
	"$concurrent_root" "$metadata_target"
flock "$index_fixture.lock" bun "$repo_root/bin/jj-workspace-store-path.ts" \
	"$index_fixture" "$repo_store" concurrent-one \
	"$metadata_target" "$concurrent_root"

if ! cmp -s "$index_fixture" "$expected_index"; then
	print -ru2 -- "FAIL: metadata helper did not preserve unknown protobuf fields"
	exit 1
fi

if [[ "$(cd "$main" && jj prewarm status)" != "absent" ]]; then
	print -ru2 -- "FAIL: jj prewarm alias did not invoke jj-prewarm"
	exit 1
fi

primary_guard="$test_root/primary-guard"
jj git init "$primary_guard" >/dev/null
print -r -- "must survive" >"$primary_guard/sentinel"
jj -R "$primary_guard" workspace rename prewarm >/dev/null
if (
	cd "$primary_guard"
	"$repo_root/bin/jj-prewarm" remove >/dev/null 2>&1
); then
	print -ru2 -- "FAIL: remove accepted an unowned primary workspace"
	exit 1
fi
if [[ ! -f "$primary_guard/sentinel" ]]; then
	print -ru2 -- "FAIL: remove deleted an unowned primary workspace"
	exit 1
fi

rogue="$prewarm_pool/prewarm"
jj -R "$main" workspace add --name prewarm -r main "$rogue" >/dev/null
mkdir -p "$rogue/cache"
print -r -- "must survive" >"$rogue/cache/valuable"
cp "$stale_ownership" "$main/.jj/repo/jj-prewarm-state"
if (
	cd "$main"
	"$repo_root/bin/jj-prewarm" ensure --revision main --path "$rogue" >/dev/null 2>&1
); then
	print -ru2 -- "FAIL: ensure claimed an unowned added workspace"
	exit 1
fi
if (
	cd "$main"
	"$repo_root/bin/jj-prewarm" remove >/dev/null 2>&1
); then
	print -ru2 -- "FAIL: remove accepted an unowned added workspace"
	exit 1
fi
if [[ ! -f "$rogue/cache/valuable" ]]; then
	print -ru2 -- "FAIL: remove deleted an unowned added workspace"
	exit 1
fi

print -r -- "jj-prewarm tests passed"
