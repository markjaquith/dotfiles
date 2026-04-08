---
name: slice-branch-into-multiple-branches
description: Split one branch's changes into a stack of smaller branches or PRs, track parent relationships, and manage follow-up rebases safely.
---

## Goal

Take a large branch and turn it into multiple smaller branches or PRs with explicit parent-child relationships, minimal history churn, and a clear registry of what belongs where.

## When To Use

Invoke this skill when the user wants to:

- split a large branch into several smaller PRs
- turn one feature branch into a stacked PR series
- separate independent leaf changes from shared foundation work
- create a reusable branch stack plan before opening PRs
- recover context on an existing stacked branch setup

Strong trigger phrases include:

- `split this branch`
- `slice this into multiple PRs`
- `stacked PRs`
- `break this branch apart`
- `create child branches`

## Core Principles

- Prefer the smallest correct stack. Do not create extra branches unless they improve reviewability.
- Split by dependency boundaries, not file count alone.
- Keep shared foundation work low in the stack.
- Put independent work on sibling leaf branches when possible.
- Cherry-pick into purpose-built branches rather than repeatedly rewriting one giant branch.
- Rebase only when a parent branch tip actually changed.
- Avoid opening every PR at once unless the user asks for that explicitly.

## Information To Gather First

Before changing anything, determine:

1. The source branch to slice.
2. The intended base branch, usually `main`.
3. Whether the user already has a desired split plan.
4. Which commits are foundational versus independent.
5. Whether any branches or PRs already exist.

If the split boundaries are unclear, ask one short question about intended PR boundaries before creating branches.

## Recommended Workflow

### 1. Inspect the source branch

Review the branch history and diff against the base branch.

Preferred commands:

```bash
git branch --show-current
git log --oneline <base>..HEAD
git diff --stat <base>...HEAD
git diff <base>...HEAD
```

Use these to group work into logical slices such as:

- migrations or schema changes
- shared foundation or refactors
- API surface changes
- feature-specific integrations
- cleanup or follow-up work

### 2. Define the stack topology

Write down the planned branches before creating them.

Use a registry with at least:

- order or label
- branch name
- short purpose
- parent branch
- PR URL or PR number if opened
- state such as local, pushed, draft, merged

Also sketch the topology, for example:

```text
main
  └─ branch-1-foundation
       └─ branch-2-api
            ├─ branch-3-integration-a
            └─ branch-4-integration-b
```

If several changes depend only on the same parent, prefer sibling leaf branches instead of a deeper chain.

### 3. Create branches from the split plan

Treat the original large branch as source material, not necessarily as a PR branch.

Recommended pattern:

1. Create the first branch from the base branch.
2. Cherry-pick only the commits that belong in that slice.
3. Create each child branch from its parent branch.
4. Cherry-pick only the commits for that child.
5. Repeat until every slice has its own branch.

Typical command shape:

```bash
git checkout -b <new-branch> <parent-branch>
git cherry-pick <commit>...
```

If a commit contains mixed concerns, split it deliberately before or during the branch-slicing process instead of forcing unrelated changes into one PR.

### 4. Preserve a branch registry

Keep a compact, human-readable registry in the working notes or repo context file when the stack matters across sessions.

Include:

- full branch names
- current tip SHAs when useful
- parent branch for each branch
- whether the branch is local only, pushed, draft, open, or merged

This registry is the source of truth for future PR creation and rebases.

### 5. Open PRs with explicit bases

When creating a PR for a stacked branch, set the base to its parent branch, not always `main`.

Preferred shape:

```bash
git push -u origin <branch>
gh pr create --base <parent-branch> --head <branch>
```

Make the PR summary explain both:

- what this slice changes
- where this PR sits in the overall stack

If the stack is large, include a concise stack table showing branch order and purpose.

### 6. Update bases after merges

When a parent PR merges, update the child's PR base to the next correct branch, often `main`.

Typical command shape:

```bash
gh pr edit <pr-number> --base <new-base>
```

### 7. Rebase only when parent tips move

If a parent branch is amended, rebased, or otherwise changes tip SHA, rebase each direct child onto the new parent tip.

Capture the old parent SHA before rewriting the parent. Then rebase with:

```bash
git rebase --onto <new-parent-tip> <old-parent-tip> <child-branch>
```

If the child also has descendants, repeat the same pattern level by level.

For sibling leaves that all depend on one parent, rebase each leaf from the same old parent tip to the new parent tip.

Do not rebase branches just because time passed. Only do it when their effective parent changed or the user explicitly wants a cleanup rebase.

## Safety Rules

- Do not destroy or reset the original source branch unless the user asks.
- Do not force-push without explicit user approval.
- Do not amend already-pushed branches unless the user explicitly asks for that workflow.
- Do not open a large batch of PRs unless the user wants that.
- Avoid unnecessary rebases because they create review noise and invalidate earlier context.

## Decision Heuristics

- Put schema or migration changes in their own slice when repo rules or deployment safety require it.
- If one change enables several others, isolate it as foundation.
- If two changes can merge independently after the same parent, make them siblings.
- If CI or runtime requires a consumer and producer to land together, keep them in the same slice or move registration to the branch where the implementation exists.
- If cleanup exists only because of an earlier mistake, keep it separate unless folding it in reduces risk and the branch is still local.

## Output Expectations

When using this skill, return:

1. the proposed stack topology
2. the exact branches to create or update
3. the parent of each branch
4. any commits or commit groups assigned to each slice
5. the commands to create, push, rebase, or open PRs
6. any open questions about ambiguous boundaries

If the user wants execution rather than just planning, carry the workflow through branch creation and verification instead of stopping at a plan.
