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
origin="$test_root/origin.git"
upstream_clone="$test_root/upstream"
worktrees="$test_root/worktrees"
mock_bin="$test_root/bin"
config="$test_root/worktrunk.toml"
hooks_log="$test_root/hooks.log"
prewarm_prefix="worktree-prewarm-rec-"

function fail() {
	print -ru2 -- "FAIL: $*"
	exit 1
}

function commit_file() {
	local dir="$1" file="$2" content="$3"
	print -r -- "$content" >"$dir/$file"
	git -C "$dir" add "$file"
	git -C "$dir" commit --quiet -m "Change $file"
}

function pool_members() {
	print -l -- "$worktrees"/${prewarm_prefix}[0-9a-f][0-9a-f][0-9a-f][0-9a-f](N)
}

function recycle() {
	(cd "$repository" && wt-prewarm recycle "$@")
}

mkdir -p "$repository" "$worktrees" "$mock_bin"
git -C "$repository" init --initial-branch=main >/dev/null
git -C "$repository" config user.email "wt-prewarm@example.com"
git -C "$repository" config user.name "wt-prewarm test"
print -r -- "node_modules/" >"$repository/.gitignore"
print -r -- "fixture" >"$repository/README.md"
print -r -- "unchanged" >"$repository/stable.txt"
git -C "$repository" add .gitignore README.md stable.txt
git -C "$repository" commit --quiet -m "Initial fixture"
git clone --quiet --bare "$repository" "$origin"
git -C "$repository" remote add origin "$origin"
git -C "$repository" fetch --quiet origin
git -C "$repository" remote set-head origin main >/dev/null
git clone --quiet "$origin" "$upstream_clone"
git -C "$upstream_clone" config user.email "wt-prewarm@example.com"
git -C "$upstream_clone" config user.name "wt-prewarm test"

cat >"$config" <<EOF
worktree-path = "$worktrees/{{ branch | sanitize }}"
pre-remove = "printf 'pre %s\\\\n' '{{ branch }}' >>'$hooks_log'"

[post-remove]
log = "printf 'post %s %s\\\\n' '{{ branch }}' '{{ worktree_path }}' >>'$hooks_log'"
EOF

cat >"$mock_bin/cowtree" <<'EOF'
#!/bin/sh
[ "$1" = "add" ] || exit 2
shift
exec git worktree add --quiet "$@"
EOF
chmod +x "$mock_bin/cowtree"

export PATH="$mock_bin:$repo_root/bin:$PATH"
export WORKTRUNK_CONFIG_PATH="$config"
export WT_PREWARM_PREFIX="$prewarm_prefix"

# A finished feature worktree: one commit of its own, warm ignored files.
git -C "$repository" worktree add --quiet -b feature "$worktrees/feature" main
commit_file "$worktrees/feature" feature.txt "feature work"
mkdir -p "$worktrees/feature/node_modules"
print -r -- "dependency" >"$worktrees/feature/node_modules/dep.txt"
stable_inode=$(stat -f %i "$worktrees/feature/stable.txt")

# origin/main advances without local main moving.
commit_file "$upstream_clone" README.md "updated"
git -C "$upstream_clone" push --quiet origin main
git -C "$repository" fetch --quiet origin
upstream_head=$(git -C "$repository" rev-parse origin/main)

# Unpushed, unmerged commits are refused without --force.
if recycle feature 2>/dev/null; then
	fail "recycle accepted a branch with unintegrated commits"
fi
git -C "$repository" show-ref --verify --quiet refs/heads/feature \
	|| fail "refused recycle deleted the branch"
[[ -f "$worktrees/feature/feature.txt" ]] || fail "refused recycle touched the worktree"
[[ -z "$(pool_members)" ]] || fail "refused recycle added a pool member"

# Once pushed to its upstream, the branch is safe to recycle.
git -C "$worktrees/feature" push --quiet -u origin feature
recycle feature 2>/dev/null

git -C "$repository" show-ref --verify --quiet refs/heads/feature \
	&& fail "recycle did not delete the branch"
[[ ! -e "$worktrees/feature" ]] || fail "recycle left the old worktree path"
members=("${(@f)$(pool_members)}")
[[ ${#members} -eq 1 && -n "${members[1]}" ]] || fail "recycle did not add one pool member"
member="${members[1]}"
[[ -f "$member/.wt-prewarm-ready" ]] || fail "recycled member is not claimable"
[[ "$(git -C "$member" rev-parse HEAD)" == "$upstream_head" ]] \
	|| fail "recycled member is not at origin/main"
[[ "$(<"$member/README.md")" == "updated" ]] || fail "recycled member missed base changes"
[[ ! -e "$member/feature.txt" ]] || fail "recycled member kept branch-only files"
[[ -f "$member/node_modules/dep.txt" ]] || fail "recycle discarded ignored files"
[[ "$(stat -f %i "$member/stable.txt")" == "$stable_inode" ]] \
	|| fail "recycle rewrote an unchanged file"
[[ -z "$(git -C "$member" status --porcelain --untracked-files=no)" ]] \
	|| fail "recycled member is dirty"
member_branch=$(git -C "$member" symbolic-ref --short HEAD)
git -C "$repository" config "branch.${member_branch}.merge" >/dev/null \
	&& fail "recycled member branch tracks a remote"
grep -qx "pre feature" "$hooks_log" || fail "recycle did not run pre-remove hooks"
for _ in {1..50}; do
	grep -qx "post feature $worktrees/feature" "$hooks_log" 2>/dev/null && break
	sleep 0.1
done
grep -qx "post feature $worktrees/feature" "$hooks_log" \
	|| fail "recycle did not run post-remove hooks for the old worktree"

# Dirty worktrees are refused; --force discards untracked files but keeps
# ignored ones.
git -C "$repository" worktree add --quiet -b dirty "$worktrees/dirty" origin/main
print -r -- "scratch" >"$worktrees/dirty/scratch.txt"
mkdir -p "$worktrees/dirty/node_modules"
print -r -- "dependency" >"$worktrees/dirty/node_modules/dep.txt"
if recycle dirty 2>/dev/null; then
	fail "recycle accepted a worktree with untracked changes"
fi
[[ -f "$worktrees/dirty/scratch.txt" ]] || fail "refused recycle discarded untracked files"
recycle --force "$worktrees/dirty" 2>/dev/null
dirty_member=$(git -C "$repository" worktree list --porcelain \
	| sed -n 's/^worktree //p' | grep -v -e "^$repository\$" -e "^$member\$")
[[ -n "$dirty_member" && ! -e "$dirty_member/scratch.txt" ]] \
	|| fail "forced recycle kept untracked files"
[[ -f "$dirty_member/node_modules/dep.txt" ]] || fail "forced recycle discarded ignored files"

# A squash-merged branch has no reachable commits on origin/main, but merging
# it would change nothing, so it is recycled without --force. Running from
# inside the worktree asks the shell to move to the main worktree.
git -C "$repository" worktree add --quiet -b squashed "$worktrees/squashed" main
commit_file "$worktrees/squashed" squashed.txt "squashed work"
commit_file "$upstream_clone" squashed.txt "squashed work"
git -C "$upstream_clone" push --quiet origin main
git -C "$repository" fetch --quiet origin
cd_file="$test_root/cd-directive"
(
	cd "$worktrees/squashed"
	WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" wt-prewarm recycle 2>/dev/null
) || fail "recycle refused a squash-merged branch"
[[ "$(<"$cd_file")" == "$repository" ]] \
	|| fail "recycle from inside did not direct the shell to the main worktree"
[[ $(pool_members | wc -l) -eq 3 ]] || fail "pool does not hold all recycled members"

# If the worktree cannot be moved (here, because it is locked), recycle rolls
# back: same branch and commit, original files, no leftover pool branch.
git -C "$repository" worktree add --quiet -b locked "$worktrees/locked" main
commit_file "$worktrees/locked" locked.txt "locked work"
locked_head=$(git -C "$worktrees/locked" rev-parse HEAD)
git -C "$repository" worktree lock "$worktrees/locked"
prewarm_branch_count=$(git -C "$repository" for-each-ref "refs/heads/${prewarm_prefix}*" | wc -l)
recycle --force locked 2>/dev/null && fail "recycle succeeded on a locked worktree"
[[ "$(git -C "$worktrees/locked" symbolic-ref --short HEAD)" == "locked" ]] \
	|| fail "rollback did not restore the branch"
[[ "$(git -C "$worktrees/locked" rev-parse HEAD)" == "$locked_head" ]] \
	|| fail "rollback moved the branch"
[[ -f "$worktrees/locked/locked.txt" && "$(<"$worktrees/locked/README.md")" == "fixture" ]] \
	|| fail "rollback did not restore the files"
[[ -z "$(git -C "$worktrees/locked" status --porcelain)" ]] || fail "rollback left the worktree dirty"
[[ $(git -C "$repository" for-each-ref "refs/heads/${prewarm_prefix}*" | wc -l) -eq $prewarm_branch_count ]] \
	|| fail "rollback left a pool branch behind"
git -C "$repository" worktree unlock "$worktrees/locked"

# --keep-branch recycles a worktree with unpushed commits and leaves its branch
# intact, as Agency's worktree removal contract requires.
git -C "$repository" worktree add --quiet -b kept "$worktrees/kept" main
commit_file "$worktrees/kept" kept.txt "kept work"
kept_head=$(git -C "$worktrees/kept" rev-parse HEAD)
member_count=$(pool_members | wc -l)
recycle --keep-branch "$worktrees/kept" 2>/dev/null \
	|| fail "recycle --keep-branch refused unpushed commits"
[[ ! -e "$worktrees/kept" ]] || fail "recycle --keep-branch left the old worktree path"
[[ "$(git -C "$repository" rev-parse --verify --quiet refs/heads/kept)" == "$kept_head" ]] \
	|| fail "recycle --keep-branch did not preserve the branch"
git -C "$repository" worktree list --porcelain | grep -qx "branch refs/heads/kept" \
	&& fail "recycle --keep-branch left the branch checked out"
[[ $(pool_members | wc -l) -eq $(( member_count + 1 )) ]] \
	|| fail "recycle --keep-branch did not add a pool member"

# Guard rails.
recycle "$repository" 2>/dev/null && fail "recycle accepted the main worktree"
recycle "$member_branch" 2>/dev/null && fail "recycle accepted a prewarm"
recycle no-such-branch 2>/dev/null && fail "recycle accepted a missing worktree"

# A recycled member is claimed like any other.
(cd "$repository" && wt-prewarm prepare --create claimed-after-recycle 2>/dev/null)
[[ -d "$worktrees/claimed-after-recycle" ]] || fail "recycled member could not be claimed"

print -r -- "wt-prewarm recycle tests passed"
