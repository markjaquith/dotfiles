---
description: Create a git commit
agent: fast
subtask: true
---

# Create a git commit for the current changes

## Process

1. Review the staged and unstaged changes
2. Analyze the changes
3. Analyze previous commits to see the commit style
4. Write a meaningful commit message in the style of previous commits

## Arguments

If the argument is "staged" ($1 = "staged"), only commit the staged files without adding any additional files. Otherwise, add all files before committing.

## Rules

NEVER use `--no-verify` or otherwise bypass precommit hooks. If precommit hooks fail, report the parent to the parent task.

NEVER use `--amend` or modify previous commits.

After successfully committing, ALWAYS output the commit hash, and the commit message, and then prompt the user for the next action. You MUST NOT perform any further actions without user confirmation, after confirming the commit has been made.
