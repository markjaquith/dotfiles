---
description: Resolve git conflicts and continue
agent: fast
---

# Resolve current git conflicts and continue the interrupted operation

I am in the middle of an interrupted Git operation such as a rebase,
cherry-pick, merge, or stash apply. Resolve the conflicts automatically, make
the required commit with `--no-verify`, and continue the operation that was in
progress.

## Process

1. Determine the interrupted operation from `git status --short --branch` and
   Git state files such as `.git/rebase-merge`, `.git/rebase-apply`,
   `.git/CHERRY_PICK_HEAD`, `.git/MERGE_HEAD`, and `.git/sequencer`.
2. Identify all conflicted files with `git diff --name-only --diff-filter=U`
   and inspect the relevant conflict regions.
3. Resolve conflicts directly. Prefer the resolution that preserves the user's
   requested final behavior over mechanically choosing ours or theirs.
4. Run the narrowest relevant checks for the files touched, when practical.
5. Stage resolved files with `git add`.
6. Create the conflict-resolution commit with `git commit --no-verify`. Reuse
   Git's prepared message when one exists; otherwise write a concise message
   describing the resolution.
7. Continue the interrupted operation:
   - rebase: `git rebase --continue`
   - cherry-pick: `git cherry-pick --continue` if a sequencer still needs it
   - merge: no separate continue step after the commit
   - stash apply: no separate continue step after the commit
8. If continuing reveals another conflict, repeat the same resolve, commit with
   `--no-verify`, and continue cycle until the operation is complete or a real
   blocker remains.
9. Finish by reporting the final `git status --short --branch`, commits made,
   and any checks run.

## Rules

Use `--no-verify` for commits made by this command. This command intentionally
bypasses hooks because it is for completing interrupted conflict-resolution
workflows.

Do not abort, skip, reset, or otherwise discard work unless explicitly asked.

Do not revert unrelated changes. If unrelated dirty files exist, leave them
alone unless they are part of the conflict.

If no Git operation or conflicts are in progress, stop and report the current
status instead of creating a commit.
