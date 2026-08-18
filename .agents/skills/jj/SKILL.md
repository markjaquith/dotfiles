---
name: jj
description: Use this skill whenever using the jj VCS CLI tool.
---

# jj

Assume other agents and processes may modify the jj repository concurrently.
Use stable change IDs and explicit revision arguments for every mutation.

## Concurrent Safety

- Use a dedicated jj workspace for each agent or task. Do not perform
  implementation work in a workspace shared with another agent.
- Do not use positional revsets such as `@` or `@-` as mutation targets in a
  concurrently accessed repository.
- Resolve intended revisions to stable change IDs immediately before each
  mutation. Verify their descriptions, parents, descendants, bookmarks,
  conflicts, and relationship to the working copy.
- Recompute every revision argument after any command reports `Concurrent
  modification detected`. Treat that message as a mandatory revalidation
  boundary: stop the command sequence, run `jj status`, inspect the relevant
  graph, and verify all targets again.
- Never assume a prior `jj log`, `jj status`, or bookmark lookup remains current
  after another command runs.

## Explicit Mutations

Prefer explicit commands such as:

```sh
jj rebase -s <source-change-id> -d <destination-change-id>
jj squash --from <resolution-change-id> --into <target-change-id>
jj describe -r <change-id> -m "description"
jj abandon -r <change-id>
```

- Never run unqualified `jj squash`, `jj abandon`, `jj rebase`, or `jj new` in a
  concurrently accessed repository.
- For `jj rebase`, always provide an explicit source with `-s` or `-b` and an
  explicit destination with `-d`.
- After resolving conflicts in a child change, use explicit `--from` and
  `--into` change IDs when squashing the resolution. Do not assume the
  resolution remains at `@`.
- Before abandoning, describing, editing, or creating descendants of a change,
  verify the exact change ID again.

## Conflict Workflow

1. Inspect the conflicted change and its current graph using stable change IDs.
2. Create or identify a dedicated resolution change without relying on the
   working-copy position.
3. Resolve files and run focused verification.
4. Reinspect the graph immediately before folding the resolution.
5. Run `jj squash --from <resolution-change-id> --into <target-change-id>`.
6. Verify the target is conflict-free and contains only the intended diff.

## Publishing

Before pushing or creating a pull request:

- Verify the target bookmark points to the intended change ID.
- Verify its ancestry contains only the expected changes.
- Verify the published commit contains the intended diff and no unrelated task
  work.
- Verify the working copy is clean.
- If concurrent modification occurs during publication, stop and repeat all
  publication checks before retrying.

When a command's safe explicit form is unclear, inspect `jj <command> --help`
instead of relying on positional defaults.
