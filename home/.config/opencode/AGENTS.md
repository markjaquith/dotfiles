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
2. Start a temporary OpenCode setup agent in the new tab's root pane with
   `--mini --model openai/gpt-5.6-sol` and low reasoning effort. The mini flag
   selects the compact interface, not the model. This agent interprets the item
   specification; a tested helper performs the mechanical setup.
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
   requested. Capture its exact absolute document path from that output. Do not
   launch work as part of creation. A creation failure ends the protocol.
2. Invoke `agency-herdr-setup <document-path> --intent open` for open/view, or
   `agency-herdr-setup <document-path> --intent launch` for work/launch/start/kick
   off. Quote the path. Run the helper once, in the temporary setup pane with
   its inherited Herdr environment; do not override caller IDs.

The helper owns context inspection, tab naming, preparation, the unfocused
worker-left/editor-right layout, launch, a bounded startup wait (60 seconds by
default), one final context verification, and closing the setup pane on success.
It prepares only execution tasks/phases, not epic or multi-phase orchestration.
It creates the editor before waiting for the worker and preserves recovery panes
on failure. Do not duplicate its commands, append extra context verification,
or rerun it after partial failure: use its emitted pane IDs for recovery.

Do not automatically use `--force` for blocked dependencies. The installed
Agency contract also overrides active worktree locks; it is not a readiness-only
override. Preserve the visible blocked layout instead. If the helper is missing
or fails, leave the setup pane open and report the error rather than improvising
the transaction. See `~/dotfiles/docs/agency-herdr-setup.md` for recovery details.

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
