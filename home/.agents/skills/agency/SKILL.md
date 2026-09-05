---
name: agency
description: >
  Operate Agency workbases, epics, tasks, phases, execution worktrees, claims,
  and pull requests. Use when inspecting or changing Agency-managed work,
  coordinating dependencies, launching agents, or finishing an execution unit.
license: MIT
compatibility: Requires the agency CLI and Git. Agent launch requires OpenCode, Claude, or a configured runner; default GitHub delivery requires gh.
---

# Agency

Agency keeps plans and lifecycle state in durable Markdown documents. Git
checkouts under `code/` are materialized local state. Treat the documents as the
source of truth and Agency commands as the safe way to mutate their structure.

## Start With Context

For an entity target, the first inspection command is:

```bash
agency context . --json
```

It identifies the target and ancestors, document revisions, dependency
readiness, write authority, checkout state, PR state, and validation warnings.
Use its paths and IDs instead of inferring them from the process cwd.

At the workbase root, context cannot infer one entity from `.`. Use
`agency next --json` or `agency graph --json` to choose a target, then inspect its
returned document path. For a known phase, use `agency phase show <task> <phase>
--json` to obtain its path and branch, then `agency context <document-path> --json`.
Do not pass a graph node key or two positional arguments to `agency context`.

For broader orchestration, load the graph and validate the workbase:

```bash
agency graph --json
agency doctor --json
```

When a known workflow's exact syntax is missing, inspect only
`agency <command> --help`. Do not run broad help or discovery for a prescribed
fast path.

Use `agency next --json` when choosing ready execution work. Treat JSON output
and the returned document paths as authoritative; do not infer missing fields.

## Mental Model

- A **workbase** contains durable epics, tasks, phases, and repository aliases.
- An **epic** coordinates tasks. It may inspect repositories but never writes code.
- A **task** is one durable outcome. It is either an execution unit itself or a
  container for phases.
- A **phase** is one execution unit within a multi-phase task, normally one PR.
- An **execution unit** has exactly one writable `repo`, optional read-only
  `repos`, one branch, one base, and one recorded PR value.
- `open` is eligible for readiness evaluation, `working` is actively owned, and
  `done` or `dropped` is terminal. An open unit may still be blocked; only `done`
  satisfies a dependency.

The `authority` returned by context is decisive. Write only through
`authority.writable.checkoutPath`. Every entry in `authority.references` is
read-only, even if filesystem permissions permit writes.

## Decide Before Acting

Require explicit user intent before:

- initializing a workbase;
- adding, linking, renaming, or removing a repository alias;
- launching another agent with `agency work` from an active agent session;
- creating a pull request;
- archiving, restoring, dropping, or reopening work; or
- using `--force` to override readiness.

Use a single-phase task for one outcome delivered by one PR. Use phases when an
outcome needs multiple PRs or ordered execution units. Use an epic when several
independently meaningful tasks need coordination.

When interpreting an orchestration handoff, explicit new-item language wins over
reuse. For example, "the investigation is complete" followed by a request for a
"new", "separate", or "follow-up coding task" establishes a distinct Agency
item even if the investigation task permits implementation. Treat permission to
implement and intent to reuse an item as separate decisions.

Keep action semantics distinct: **create** mutates durable state only,
**materialize** runs `agency work prepare` only, **open** starts `agency work`
without `--auto`, and **launch/work/start** starts it with `--auto`. Do not turn a
create-only or materialize-only request into an agent launch or UI operation.
More-specific workbase instructions remain authoritative for managed fast paths.

## Safety Invariants

- Keep task-wide decisions in `TASK.md` and phase delivery details in `PHASE.md`.
- Never write through plural `repos` references.
- Never edit bare repositories or repository symlinks under `repos/`.
- Never manually create, move, or remove generated `code/` worktrees.
- Never invent IDs, revisions, PR URLs, dependency completion, or checkout state.
- Preserve parent backlinks and dependency declarations; use Agency mutations
  instead of hand-editing structural frontmatter.
- Run `agency validate` before worktree or PR operations and after structural edits.
- Do not bypass dirty-worktree, active-claim, revision, or readiness protections.
  Do not automatically force chained-phase setup: the installed `--force` also
  overrides active worktree locks, not just dependency readiness.

## Operating Protocol

### Start

1. Run `agency context . --json`.
2. Confirm `target`, `graph.readiness`, `authority`, `workspace`, and `validation`.
3. Read the returned task and phase document paths for prose requirements.
4. Stop on validation errors, an unexpected writable repository, a conflicting
   active owner, or any workspace warning containing `Unable to resolve
   reference`. Stop on dependency blockers. For an active
   agent, a `working` status blocker is expected only when the current session
   owns the claim. Never use `--force` for unresolved references or other safety
   failures.

### Work

1. Change files only in the declared writable checkout.
2. Keep durable status and decisions current as the work changes.
3. Validate structure after Agency document mutations.
4. Run repository-specific formatting, type checks, builds, dead-code checks,
   and focused tests before committing.
5. Review the diff and commit according to the repository's instructions.

### Finish

1. Re-run `agency validate` and repository checks.
2. Create a PR only when requested. Before mutation, require the execution unit
   to declare a base and stop if a user-requested base differs from it. Create
   through `agency pr create <task> [phase]`, never a parallel provider command.
3. Read the created PR back from the provider and require its actual base and
   head to match the Agency-declared base and branch. For GitHub, use
   `gh pr view` with explicit repository and branch selectors. Report the
   requested base, Agency-declared base, and actual base; treat any mismatch as
   a failed publication instead of silently retargeting it.
4. Record terminal state only when the requested outcome is true. A created PR
   alone does not make work `done` if completion requires merge.
5. If the session has a claim, use revision-guarded `agency finish`; otherwise
   use the task or phase status command. Use `dropped` only for intentionally
   abandoned work.
6. Report the durable status and PR URL. Do not manually remove the worktree.

## Human Launch vs Active Agent

`agency work` is a human/orchestrator launch flow. It first reconciles managed
integration files, then selects work and checks readiness. For an execution unit,
it materializes managed checkouts, claims the unit, marks it working, and starts
the selected built-in or configured runner. Epic and multi-phase task launches
start in orchestration context without materializing or claiming execution work.

Before launching execution work, preflight workspace preparation and inspect the
JSON result:

```bash
agency work prepare <item-directory> --dry-run --json
```

Do not launch if the command fails, validation fails, or it reports an
`Unable to resolve reference` workspace warning. Do not automatically retry with
`--force`: the installed contract overrides active worktree locks as well as
readiness. A failed preparation does not
prevent the orchestrator from creating an unlaunched worker shell and editor as
a recovery layout. Resolve repository-reference failures before launch. Do not
use the legacy `agency worktree prepare` path.

For the dotfiles-managed initiating-agent flow, invoke
`agency-herdr-dispatch --intent open|launch --request '<complete user request>'`
after required bootstrap. Do not investigate branches, model settings, or pane
layout before dispatch; the generated setup protocol owns narrow item lookup.
Branch ancestry is not a completion dependency: never infer `--depends-on` solely
from the requested base branch, and preserve existing explicit gates.

Only the temporary setup agent invokes
`agency-herdr-setup <absolute-document-path> --intent open|launch` once instead
of executing the mechanical steps individually. It performs execution-only
preparation, preserves an unfocused recovery layout, and bounds worker startup.
Epics and multi-phase task orchestration do not use execution preparation.
The helper closes the temporary setup pane itself on success; quiet successful
Herdr pane run/close commands do not require JSON output.

An explicitly authorized start despite working dependencies may use the dedicated
`--allow-working-dependencies` flag when the selected CLI supports it. This is
invocation-scoped permission, not an instruction to remove dependencies or enable
`--force`. A verified managed development CLI can be selected for that invocation
with `--agency-executable`; do not change the global installation as a workaround.

An agent already running in an Agency checkout must not call `agency work` to
start itself again. It should inspect context, perform the assigned work, and
finish or release its existing claim. Launch a nested or replacement agent only
when the user explicitly asks.

For recovery or an unfamiliar mutation, inspect only the narrow relevant
`agency <command> --help` after reading current context.
