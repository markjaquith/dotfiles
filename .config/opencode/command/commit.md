---
description: Create a git commit
agent: fast
subtask: true
---

Create a git commit for the current changes. Review the staged and unstaged changes, analyze the changes, write a meaningful commit message in the style of previous commits.

If the argument is "staged" ($1 = "staged"), only commit the staged files without adding any additional files. Otherwise, add all files before committing.

After committing, output the commit hash, and the commit message, and then prompt the user for the next action. You MUST NOT perform any further actions without user confirmation, after confirming the commit has been made.
