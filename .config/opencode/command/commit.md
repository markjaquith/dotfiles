---
description: Create a git commit
agent: fast
subtask: true
---

# Create a git commit for the current changes

Prioritize speed: gather all commit context in one pass, then commit.

## Process

1. Gather context in parallel with a single multi-tool call:
   - `git status --short --branch`
   - `git diff --staged`
   - `git diff`
   - `git log -12 --pretty=format:%h%x09%s`
2. Analyze the full diff and recent commit style.
3. Draft a concise message that explains intent (not just file names).
4. Commit immediately once message is ready.
5. Run `git status --short --branch` after commit to verify a clean/expected state.

## Arguments

If the argument is "staged" ($1 = "staged"), only commit the staged files without adding any additional files. Otherwise, add all files before committing.

Implementation detail:

- If not `staged`, stage once with `git add -A` before committing.
- Do not run extra exploratory commands beyond the context-gathering step unless needed to resolve an error.

## Rules

NEVER use `--no-verify` or otherwise bypass precommit hooks. If precommit hooks fail, report the parent to the parent task.

NEVER use `--amend` or modify previous commits.

Prefer one parallel context-gathering step over sequential reads to reduce latency.

After successfully committing, ALWAYS output the commit hash, and the commit message, and then prompt the user for the next action. You MUST NOT perform any further actions without user confirmation, after confirming the commit has been made.
