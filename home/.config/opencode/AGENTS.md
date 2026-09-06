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

After the active-worker check and any required workbase bootstrap, the initiating
agent invokes exactly one dispatch command:

```sh
agency-herdr-dispatch --intent launch --request '<complete original user request>'
```

Use `--intent open` for open/view. Preserve the full request, including multiline
requirements; quote it safely. The default cwd is the current directory. Pass
`--cwd <known-directory>` only when the user requests a different location.
The dispatcher verifies caller metadata, creates an unfocused tab in the caller's
workspace, selects a setup-only low-effort OpenCode profile, and submits the
protocol and original request. It does not change implementation-worker defaults.
Exit zero means **dispatch accepted**, not **task started**.

The initiating agent must not resolve the predecessor branch, glob task checkouts,
list tabs, inspect model configuration, search for reasoning-effort settings, or
rediscover Herdr/OpenCode command syntax before dispatch. Those are not kickoff
prerequisites. Return when dispatch is accepted; do not poll or babysit unless
the user explicitly requests monitoring. Do not manually duplicate the dispatch
transaction when it fails or times out; retain returned IDs for recovery.

The temporary setup agent owns only narrow item lookup and requested creation,
then invokes `agency-herdr-setup <absolute-document-path> --intent open|launch`
once. Its complete protocol is generated by the dispatcher. For missing phase
branch/path data, use `agency phase show <task-id> <phase-id> --json`, then the
returned document path with `agency context`; never use a recursive checkout glob
or invent positional context syntax. Preserve the actual work requirements in
the durable document before launch. A creation failure ends setup and sends a
native Herdr failure notification, without focusing or typing into another pane.

The helper owns context inspection, tab naming, preparation, the unfocused
worker-left/editor-right layout, launch, a bounded startup wait (60 seconds by
default), one final context verification, and closing the setup pane on success.
It prepares only execution tasks/phases, not epic or multi-phase orchestration.
It creates the editor before waiting for the worker and preserves recovery panes
on failure. Do not duplicate its commands, append extra context verification,
or rerun it after partial failure: use its emitted pane IDs for recovery.
When invoking the helper through a Bash tool, set its enclosing timeout to
1200000ms, not the default 120000ms. The budget must cover preparation, startup,
verification, and cleanup; it is a maximum, not a delay. Keep earlier item
creation and metadata updates in separate tool calls.

Branch ancestry is not a completion gate: "based on round 4's branch" sets the
base, not `--depends-on round-4`. Add a gate only when requested; never remove an
existing dependency or mark it done just to make launch succeed.

When the user explicitly authorizes starting despite existing working
dependencies, pass `--allow-working-dependencies` to the dispatcher and helper.
The selected Agency CLI must support that readiness-only flag. Never fall back
to `--force`, which can bypass unrelated safeguards. For an explicitly approved
development CLI, `--agency-executable <absolute-path>` selects it for that run
without modifying the global installation.
Carry the explicit start-now approval into the durable item's decisions before
launch. An active worker with that documented or directly supplied approval
should not ask again about the same preserved working dependency; all other
safety checks remain in force, and later invocations need their own approval.

On success the helper closes the temporary setup pane itself, leaving only the
worker/editor layout. A successful, silent `herdr pane run` or `pane close` is
normal, not a JSON failure. On failure retain recovery panes and report once via
the originating-pane metadata; never inject input into the originating agent.
Do not rerun the whole helper after partial success. For explicitly requested
recovery, inspect the existing panes and finish only the missing step, including
self-close once worker, editor, and authority have been verified.

See `~/dotfiles/docs/agency-herdr-dispatch.md` and
`~/dotfiles/docs/agency-herdr-setup.md` for contracts and recovery details.

Agency development itself belongs in a new Agency-managed task in the registered
development workbase (currently `~/Dev/workbase`). Launch and work that task;
write implementation only in its context-declared checkout. Standalone
`~/Dev/agency` or `~/Dev/agency2` checkouts are not development targets;
`~/Dev/agency2` may be read to recover a draft, then adapt it to current main.

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
