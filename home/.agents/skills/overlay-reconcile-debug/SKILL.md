---
name: overlay-reconcile-debug
description: Diagnose dotfiles overlay issues involving local overrides, symlinks, skip-worktree drift, pure mode, and .git/info/exclude consistency.
---

## Purpose

Use this skill to debug the boundary between the tracked `~/dotfiles` repo and one or more local overlay directories such as `~/.local-dotfiles`.

The goal is to identify whether the source of truth lives in the repo, an overlay, or the live working tree, then reconcile symlinks, `skip-worktree`, and `.git/info/exclude` together.

## When To Use

Invoke this skill when the user mentions any of the following:

- `overlay`, `local-dotfiles`, `override`, `pure mode`, or `dotfiles --pure`
- missing local overrides or unexpected repo files in `$HOME`
- `skip-worktree`, `.git/info/exclude`, or overlay symlink drift
- `bin/dotfiles-install-overlay.zsh` or `bin/dotfiles-overlay-doctor`

Strong trigger phrases include:

- `why is my overlay not applying`
- `why did this become untracked`
- `why did --pure remove this`
- `why is this symlink broken`
- `why is git status noisy after overlay changes`

## Default Workflow

1. State the boundary clearly: identify whether the relevant source of truth appears to be in `~/dotfiles`, `~/.local-dotfiles`, or another overlay directory.
2. Read the nearby overlay scripts before changing behavior:
   - `bin/dotfiles-install-overlay.zsh`
   - `bin/dotfiles-overlay-doctor`
3. Use the doctor first when possible:

```bash
bin/dotfiles-overlay-doctor
```

4. If needed, inspect Git state that affects overlays:

```bash
git ls-files -v
git status --short
```

5. Check `.git/info/exclude` handling if untracked-file noise is part of the bug.
6. Treat these as a single system, not isolated mechanisms:
   - active symlink target
   - desired overlay source file
   - `skip-worktree` bit for tracked files
   - `.git/info/exclude` entries for overlay-only files
7. Propose or implement the narrowest fix that keeps those mechanisms aligned.

## Repo-Specific Heuristics

- In this repo, fixing only the symlink is often incomplete.
- If the overlay file corresponds to a tracked repo path, verify the related `skip-worktree` bit.
- If the overlay file does not correspond to a tracked repo path, verify `.git/info/exclude` behavior.
- In `DOTFILES_PURE=1` mode, expect the desired overlay set to be empty and active overrides to be cleaned up.
- When the user reports that an alias or config value is "missing," confirm whether it comes from the repo or a local overlay before editing anything.

## Output Expectations

Return findings in this order:

1. `Boundary` - where the source of truth appears to live
2. `Observed State` - the concrete broken or unexpected behavior
3. `Mismatch` - which of symlink, skip-worktree, exclude, or pure-mode expectations are out of sync
4. `Fix` - the smallest safe change or command sequence
5. `Verify` - the exact narrow checks to confirm the fix

## Failure Modes To Avoid

- Editing repo files when the real source of truth is a local overlay
- Fixing `skip-worktree` without checking the symlink target
- Fixing the symlink but leaving noisy untracked files because `.git/info/exclude` was ignored
- Treating `dotfiles --pure` cleanup as a regression when it matches pure-mode intent
- Reverting unrelated local overlay state that the user intentionally maintains outside the repo

## Verification Checklist

Before finishing, check:

- Did I identify repo vs overlay ownership explicitly?
- Did I inspect both overlay scripts if behavior may be install-time rather than diagnosis-time?
- Did I account for symlink, `skip-worktree`, and `.git/info/exclude` together?
- Did I give the user exact verification steps?
