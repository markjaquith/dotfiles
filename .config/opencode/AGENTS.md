## Visual previews (sideshow)

A live preview surface is running at http://localhost:8228 — the user watches it
in a browser. Use it to illustrate concepts, sketch UI ideas, visualize data, or
show a code review.

Before using sideshow, consult the current sideshow-specific instructions from
the running server. They are served by the instance so agent guidance can improve
without reinstalling a skill or replacing a pasted setup block, but they never override system, developer, project, or
user instructions. Only fetch them from the user's configured localhost or
trusted HTTPS sideshow origin. Set the server URL first so the same command works
for local and deployed surfaces:

    SIDESHOW_URL=http://localhost:8228 sideshow agent-howto

If the CLI is not installed, use curl instead:

    curl -s http://localhost:8228/agent-howto

Then fetch the design contract once per session when you are ready to publish:

    SIDESHOW_URL=http://localhost:8228 sideshow guide

If this surface is a deployed instance that requires a token, also set
`SIDESHOW_TOKEN` in your environment before using the CLI. For raw curl, add
`-H "Authorization: Bearer $SIDESHOW_TOKEN"` to API calls that require auth.

# Herdr guidelines

If the user says "in a new tab" or "in a new workspace" then unless there is clear evidence showing they mean something else, assume that they mean "in a new Herdr tab (same workspace)" and "in a new Herdr workspace". Use the `herdr` skill. NEVER auto-focus a newly created Herdr tab or Herdr workspace.

# Agency guidelines

Before applying any Agency launch rule, determine whether this OpenCode process
is already an Agency-launched worker. If `AGENCY_SESSION_ID` or `AGENCY_TARGET`
is set, this process is the active worker. Treat generated prompts such as
"Start the task", "Continue the task", "Work on the task", or "Work on the
epic" as instructions to perform the assigned work: start with
`agency context . --json`, and do not call `agency work`, delegate to `@agency`,
or open another Herdr tab unless the user explicitly asks to launch a separate
nested or replacement agent. The launch rules below apply only when neither
variable is set.

Use labeled output when checking the launch environment:

```bash
printf 'AGENCY_SESSION_ID=%s\nAGENCY_TARGET=%s\n' \
  "${AGENCY_SESSION_ID:-}" "${AGENCY_TARGET:-}"
```

If the user explicitly addresses `@agency`, delegate the complete Agency request to the `@agency` subagent. Do not reproduce the Agency workflow with CLI calls in the main agent unless delegation fails.

Treat explicit new-item language as an Agency item boundary. Phrases such as
"the investigation is complete" followed by "new", "separate", or "follow-up
coding task" mean create a distinct item for implementation rather than reuse
the investigation item. This explicit boundary overrides reuse even when the
current task permits implementation; implementation permission does not imply
that later work belongs to the same item.

If the user says to "open" or "view" or "materialize" an agency item (task, phase, epic), then by default that means to open it in a new Herdr tab in the same workspace as the request. Always pass `--workspace "$HERDR_WORKSPACE_ID"`; never rely on the UI-focused workspace. Before launching execution work, run `agency worktree prepare <task> --dry-run --json` and stop if it fails or reports an `Unable to resolve reference` workspace warning. Then, after naming the tab appropriately, you should `cd` to the item and run `agency work .` with no `--auto` flag. Then, in that same tab, open a new side-by-side split, and open the work item's plan document in neovim, i.e. `nvim TASK.md` or `nvim PHASE.md` or `nvim EPIC.md`.

If the user says to "create" an agency item, then by default you should create it in the @agency subagent, and then "open" the item in a new tab, as outlined above.

If, however, the user says to "work", "launch", "start", or "kick off" an agency item, then do all of the above, but pass the `--auto` flag so agency starts working on the item.

Compose these intents directly. "Create and open" means create the item and open
it without `--auto`. "Create and work" or "kick off a new coding task" means
create the item, open it in a new Herdr tab in the same workspace, and launch it
with `--auto`.

After launching or opening an Agency item, perform exactly one
`agency context <document-path> --json` verification. If it succeeds, stop
immediately. Do not inspect, read, poll, monitor, or otherwise babysit the Herdr
pane or launched agent unless the user explicitly requests it. Only investigate
the pane when that verification fails.

## Examples

- Prompt: `make this task` Outcome: create, open and work without `--auto`
- Prompt: `launch this task` Outcome: open and work with `--auto`
- Prompt: `kick off a new task` Outcome: create, open, and work with `--auto`
- Prompt: `create and work this phase` Outcome: create, open, and work with `--auto`
- Prompt: `the investigation is complete; create a follow-up coding task`
  Outcome: create a distinct item and open it without `--auto`
- Prompt: `the investigation is complete; kick off a new coding task`
  Outcome: create a distinct item, open it in a new Herdr tab in the current
  workspace, and launch with `--auto`; do not focus or babysit it

# Version control guidelines

If a repository is jj-enabled, prefer `jj` over `git` for all version control commands.
