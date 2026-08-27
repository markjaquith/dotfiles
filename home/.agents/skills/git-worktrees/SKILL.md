---
name: git-worktrees
description: Use whenever creating or managing git worktrees.
---

First determine whether Agency owns the checkout. If `AGENCY_SESSION_ID` or
`AGENCY_TARGET` is set, or `agency context . --json` identifies the path as an
Agency-managed checkout under an item's `code/` directory, defer all worktree
creation, preparation, and cleanup to Agency. Never run Worktrunk against an
Agency-managed worktree.

For every other Git worktree operation, you MUST use Worktrunk. Load the
`worktrunk` skill before proceeding.
