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

# Skill loading guidelines

Load each skill at most once per conversation. Reuse its already-loaded
instructions unless the skill file changed or the user explicitly asks to reload
it. Do not re-read an unchanged skill merely because the task entered a new
phase or another related skill was loaded.

# Herdr guidelines

If the user says "in a new tab" or "in a new workspace" then unless there is clear evidence showing they mean something else, assume that they mean "in a new Herdr tab (same workspace)" and "in a new Herdr workspace". Use the `herdr` skill. NEVER auto-focus a newly created Herdr tab or Herdr workspace.

# Agency guidelines

Before applying any Agency launch rule, determine whether this OpenCode process
is already an Agency-launched worker. If `AGENCY_SESSION_ID` or `AGENCY_TARGET`
is set, this process is the active worker. Treat generated prompts such as
"Start the task", "Continue the task", "Work on the task", or "Work on the
epic" as instructions to perform the assigned work: start with
`agency context . --json`, and do not call `agency work` or open another Herdr
tab unless the user explicitly asks to launch a separate nested or replacement
agent. The launch rules below apply only when neither
variable is set.

Use labeled output when checking the launch environment:

```bash
printf 'AGENCY_SESSION_ID=%s\nAGENCY_TARGET=%s\n' \
  "${AGENCY_SESSION_ID:-}" "${AGENCY_TARGET:-}"
```

Treat explicit new-item language as an Agency item boundary. Phrases such as
"the investigation is complete" followed by "new", "separate", or "follow-up
coding task" mean create a distinct item for implementation rather than reuse
the investigation item. This explicit boundary overrides reuse even when the
current task permits implementation; implementation permission does not imply
that later work belongs to the same item.

Interpret Agency action verbs as separate intents:

- **Create** (`create`, `make`, or `add`) mutates the durable Agency item only.
  Do not prepare a checkout, open Herdr UI, or run `agency work` unless the same
  request explicitly asks for one of those actions.
- **Materialize** (`materialize` or `prepare`) runs
  `agency work prepare <item-directory> --dry-run --json` and, after a clean
  preflight, `agency work prepare <item-directory> --json`. It does not open
  Herdr UI or run `agency work`.
- **Open** (`open` or `view`) constructs the Herdr worker/editor layout and runs
  `agency work .` without `--auto`.
- **Launch** (`work`, `launch`, `start`, or `kick off`) constructs that layout
  and runs `agency work . --auto`.

Combined requests compose these intents. For create-only requests, use the
appropriate noninteractive Agency mutation with `--json`, capture the returned
item ID and document path, and perform exactly one
`agency context <document-path> --json` verification. For materialize-only
requests, resolve the item directory from Agency output, stop on validation
failure or any `Unable to resolve reference` warning, and perform exactly one
context verification after preparation. Neither flow creates a Herdr tab.

Only requests that include an **open** or **launch** intent are dispatched to a
temporary setup agent in a new Herdr tab. The initiating agent must not create
the Agency item, prepare its workspace, or build the final pane layout itself
for those UI flows.

The initiating agent must:

1. Create an unfocused Herdr tab in the request's current workspace, always
   passing `--workspace "$HERDR_WORKSPACE_ID"` rather than relying on the
   UI-focused workspace. Use the current working directory and a useful
   provisional tab name.
2. Start a temporary setup agent in the new tab's root pane. Prefer the fastest
   suitable model and low reasoning effort when the selected agent supports
   those controls; this role executes a deterministic protocol.
3. Prompt it with the user's complete request, the intended Agency action, and
   the setup-agent protocol below. Submit the prompt without waiting for the
   work to settle.
4. After Herdr accepts the prompt, return immediately. Do not poll, inspect,
   verify, or babysit the setup agent unless the user explicitly requests it.

The temporary setup agent owns the rest of the launch transaction. This is a
prescribed fast path, not an investigation. It must not search for subagent
support, inspect Agency or Pi/OpenCode implementation files, read example tasks,
or run broad help or discovery commands when the direct Agency command is known.
If syntax is genuinely missing, inspect only the narrow relevant command help.

1. Create the Agency item directly with the appropriate noninteractive Agency
   CLI mutation and `--json`, or resolve the existing item when creation was not
   requested. Capture the exact item ID, document path, item directory, and plan
   filename (`TASK.md`, `PHASE.md`, or `EPIC.md`) from that output. Do not launch
   work as part of the create command.
2. Immediately rename the Herdr tab once the durable item ID is known so that
   preparation progress is visible under the final name.
3. Run `agency work prepare <item-directory> --dry-run --json`. Stop if it fails,
   validation fails, or any workspace warning contains `Unable to resolve
reference`. If preflight succeeds, run
   `agency work prepare <item-directory> --json` to materialize the workspace.
4. Split its own pane downward, with the new bottom pane's cwd set directly to
   the item directory. Keep focus unchanged.
5. In the bottom pane, run `agency work .`; add `--auto` only when the user's
   intent is to work, launch, start, or kick off the item.
6. Targeting the explicit worker pane ID, use Herdr's agent wait commands rather
   than shell polling loops. Wait only until Herdr recognizes the worker and it
   reaches an expected initial state: idle/done for an open-only request, or
   working/done for an auto-start request. Do not wait for the task itself to
   finish.
7. Split the worker pane to the right, set the editor pane's cwd to the item
   directory, and run Neovim on the plan filename. The resulting bottom subtree
   must be worker-left and plan-right.
8. Perform exactly one `agency context <document-path> --json` verification.
9. Only after worker detection and context verification succeed, close its own
   temporary top pane using its explicit `$HERDR_PANE_ID`. The bottom subtree
   then expands to become the tab's final side-by-side layout.

Batch independent or immediately sequential shell operations into as few tool
turns as practical, while still parsing every returned Herdr pane ID instead of
predicting it. Do not pause between successful protocol steps for narration or
additional planning.

The setup agent must not close its pane after any creation, preparation, launch,
worker-detection, editor-layout, or context-verification failure. It should leave
the failure visible in that pane for recovery. It must not focus the new tab or
any new pane.

Compose intents directly. "Create and open" means create the item and launch
`agency work .` without `--auto`. "Create and work" or "kick off a new coding
task" means create the item and launch `agency work . --auto`.

## Examples

- Prompt: `make this task` Outcome: create the durable item only
- Prompt: `materialize this task` Outcome: prepare its workspace only
- Prompt: `open this task` Outcome: open it in Herdr without `--auto`
- Prompt: `launch this task` Outcome: open it in Herdr with `--auto`
- Prompt: `kick off a new task` Outcome: create, open, and work with `--auto`
- Prompt: `create and work this phase` Outcome: create, open, and work with `--auto`
- Prompt: `the investigation is complete; create a follow-up coding task`
  Outcome: create a distinct durable item only
- Prompt: `the investigation is complete; kick off a new coding task`
  Outcome: create a distinct item, open it in a new Herdr tab in the current
  workspace, and launch with `--auto`; do not focus or babysit it

# Version control guidelines

If a repository is jj-enabled, prefer `jj` over `git` for all version control commands.
