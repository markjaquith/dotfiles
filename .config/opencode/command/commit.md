---
description: Create a git commit
agent: fast
subtask: true
---

# Create a git commit for the current changes

Prioritize speed: stage first when needed, gather commit context once, then
commit.

## Process

1. If the first argument is `staged`, do not add files.
2. Otherwise, run `git add -A` immediately.
3. Gather context with one shell call using only the staged snapshot:
   - `git status --short --branch`
   - `git log -8 --pretty=format:%h%x09%s`
   - `git diff --cached --stat`
   - `git diff --cached --unified=1`
4. Analyze the staged diff and recent commit style.
5. Draft a concise message that explains intent (not just file names).
6. Commit immediately once the message is ready.
7. Run `git status --short --branch` after commit to verify a clean/expected state.

## Arguments

If the first argument is `staged`, only commit the staged files without adding
any additional files. Otherwise, add all files before committing.

Implementation detail:

- If not `staged`, stage once with `git add -A` before gathering context.
- Prefer one shell call with clearly separated sections over multiple tool calls.
- Do not run extra exploratory commands beyond the context-gathering step unless needed to resolve an error.
- Default to a single-agent fast path.
- Only use a subagent for unusually large diffs where message drafting is the bottleneck.

## Rules

NEVER use `--no-verify` or otherwise bypass precommit hooks. If precommit hooks fail, report the parent to the parent task.

NEVER use `--amend` or modify previous commits.

Prefer one shell-based context-gathering step over multiple tool calls to
reduce latency.

After successfully committing, ALWAYS output:

- the commit hash
- the commit message
- a short post-commit status summary
