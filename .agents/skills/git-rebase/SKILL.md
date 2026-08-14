---
name: git-rebase
description: Use when rebasing with jj or Git, or when fixing rebase conflicts.
---

Use jj whenever `jj root` succeeds. Use Git only as a fallback.

## jj

Refresh the destination and inspect the stack before rewriting it:

```bash
jj git fetch --remote origin
jj log -r 'main@origin..@'
```

Rebase the whole stack containing `@` onto the remote main branch with:

```bash
jj rebase -b @ -o main@origin
```

Use the execution unit's declared base instead of `main@origin` when they
differ. Use `-s <revision>` only to move that revision and its descendants, or
`-r <revset>` to move exactly selected revisions while preserving their
internal dependencies. Do not substitute either form without inspecting the
graph.

jj records conflicts in the rewritten commits; there is no `rebase --continue`.
Use `jj status` and `jj resolve --list`, resolve the files, then inspect the
result with `jj diff` and `jj log`. Advance the PR bookmark to the intended tip
and publish it with `jj git push --remote origin --bookmark <bookmark>`.

## Git Fallback

When `jj root` fails, set `EDITOR=true` before Git rebase commands so an
interactive editor does not hang the session. Use the repository's normal Git
rebase flow, resolve conflicts, stage resolutions, and run
`EDITOR=true git rebase --continue`.
