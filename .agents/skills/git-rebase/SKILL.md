---
name: git-rebase
description: Use when doing a Git rebase or fixing Git rebase conflicts.
---

This skill is for Git repositories. In a jj-enabled repository, follow the
injected jj version-control guidance instead.

Set `EDITOR=true` before Git rebase commands so an interactive editor does not
hang the session. Resolve conflicts, stage the resolved files, and continue with
`EDITOR=true git rebase --continue`.
