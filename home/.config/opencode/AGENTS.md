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

Treat an external ticket key or URL used as the target of an Agency action as a
request for the corresponding Agency task. Resolve ticket-backed tasks by their
normalized ticket key, including task IDs with a slug suffix and matching
`ticketUrl` values; do not assume the task ID is exactly the ticket key. If no
matching Agency task exists, the action authorizes creating one from the remote
ticket even when the user did not separately say `create` or `new`. Fetch the
remote ticket, preserve its canonical URL and supported requirements in the new
task, and use only authoritative workbase context or ticket evidence for its
epic, repository, branch, and base. Stop rather than guess if the remote ticket
cannot be fetched, multiple Agency tasks match, or required metadata is
ambiguous. This fallback applies only when the ticket is the requested work
target, not when a ticket is merely mentioned as context or a dependency.

Combined requests compose these intents. For create-only requests, use the
appropriate noninteractive Agency mutation with `--json`, capture the returned
item ID and document path, and perform exactly one
`agency context <document-path> --json` verification. For materialize-only
requests, resolve the item directory from Agency output, stop on validation
failure or any `Unable to resolve reference` warning, and perform exactly one
context verification after preparation. Neither flow creates a Herdr tab.

Requests with an **open** or **launch** intent use one deterministic command,
run by the initiating agent itself. There is no setup agent:

```sh
agency-kickoff <target>          # launch: agency work . --auto
agency-kickoff <target> --open   # open:   agency work .
```

`<target>` is a task ID, `task-id/phase-id`, `epic:<id>`, an Agency document or
directory path, or a ticket key/URL (matched against task ID prefixes and
`ticketUrl`). Run it from inside the workbase, or pass `--workbase <selector>`.
In about a second it resolves the target, rejects archived, terminal, invalid,
or self-launch targets, runs the `agency work prepare --dry-run` preflight for
execution units, then creates an unfocused tab labeled with the target ID: worker
on the left running `agency work`, editor on the right with the item's
`TASK.md`/`PHASE.md`/`EPIC.md`. It prints one JSON line (`launched` or `error`)
and returns without waiting for the worker. If `agency work` later exits with an
error, the worker pane shows it and Herdr shows an "Agency launch failed" toast.

If creation is needed, including a ticket target with no Agency task, the
initiating agent creates the item first (fetching the remote ticket when needed,
per the rules above), then runs `agency-kickoff` with the new item's ID or
document path. For a named phase whose branch or path is unknown, use
`agency phase show <task-id> <phase-id> --json`; never glob checkouts or infer
a branch from a slug.

Do not resolve predecessor branches, list tabs, inspect model configuration, or
rediscover Herdr/OpenCode syntax before kickoff. Do not call
`opencode.session_move`; the new worker starts in its own managed context.
Return after `launched`; do not poll or babysit unless asked. On an `error`
before a tab exists, fix the reported problem (or report it) and rerun. On an
`error` that includes `tabId`, the tab is left visible: finish only the missing
step or report the IDs; do not rerun blindly and create a duplicate tab.

Branch ancestry is not a completion gate: "based on round 4's branch" sets the
base, not `--depends-on round-4`. Add a gate only when requested; never remove an
existing dependency or mark it done just to make launch succeed.

When the user explicitly authorizes starting despite existing working
dependencies, pass `--allow-working-dependencies`. Never fall back to `--force`,
which can bypass unrelated safeguards. Before launch, record that start-now
approval in the durable item's Important Decisions so the worker does not ask
again about the same preserved dependency; other safety checks and later
invocations are not waived. For an explicitly approved development CLI,
`--agency-executable <absolute-path>` selects it for that run without modifying
the global installation.

See `~/dotfiles/docs/agency-kickoff.md` for details.

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
