# Agency Herdr Dispatch

`agency-herdr-dispatch` is the initiating agent's single-command handoff for a
user-requested **open** or **launch** flow. It does not create Agency items or
inspect Agency context itself. OpenCode and Pi initiating agents can both call
it; the temporary setup agent is always OpenCode.

```sh
agency-herdr-dispatch --intent launch --request 'The complete original user request'
agency-herdr-dispatch --intent open --request 'Open the existing task' --cwd '/path/to/workbase' --label 'Task setup'
```

Pass the complete user prompt, not a summary. `--cwd` defaults to `process.cwd()`;
relative paths resolve against that directory, not `$PWD` or the focused UI.
`--label` defaults to the requested cwd's basename. Values are separate subprocess
arguments, never shell source. Requests retain whitespace, newlines, quotes, and
Unicode exactly; NUL is rejected because subprocess arguments cannot contain it.

Only invoke this command for an authorized user open/launch flow. Create-only
and materialize-only requests must not use it. Defined `AGENCY_SESSION_ID` or
`AGENCY_TARGET` blocks dispatch, including empty values. There is no automatic
nested-worker override.

## Optional Executable

To opt into a tested managed Agency CLI for this run before its release:

```sh
agency-herdr-dispatch --intent launch \
  --request 'Start the existing phase now despite its working dependencies' \
  --agency-executable '/absolute/managed/checkout/bin/agency' \
  --allow-working-dependencies
```

`--agency-executable` must be a normalized absolute path to an existing regular
file with execute permission, matching the helper contract. Relative paths,
`..` segments, trailing slashes, missing files, directories, and non-executable
files fail before any subprocess or tab allocation. Executable symlinks to files
are accepted. The dispatcher checks metadata/access only; it does not run the
selected CLI. The file needs to remain available when the setup agent and helper
use it; validation does not pin its contents.

The selected path is shell-quoted in **every** Agency command recipe, including
context, phase resolution, creation, and help, and passed to the helper as
`--agency-executable '<selected-path>'`. This supports spaces, apostrophes, and
shell metacharacters without evaluating them. Placeholder paths and other values
in recipes must be replaced with individually quoted arguments. The original
request remains verbatim and authoritative for work requirements, never shell
source. No PATH, global command, provider, model default, or install is changed.

Without this option the command remains `agency`, with no additional executable
checks. The executable selection does not itself authorize working-dependency
overrides or removing gates; `--allow-working-dependencies` still requires the
explicit user authorization described below.

## Transaction

1. Validate arguments and any explicit executable, and require `HERDR_ENV=1` and inherited workspace/tab/pane
   IDs. Verify their exact location with `herdr pane get "$HERDR_PANE_ID"`.
   IDs are opaque strings; `w3S:t21` and `w3S:p48` are valid real handles.
2. Create one tab with explicit inherited `--workspace`, requested `--cwd`,
   `--label`, `--no-focus`, and the five `--env` assignments below.
3. Start a uniquely named agent in the returned root pane with
   `herdr agent start <name> --kind opencode --pane <id> --timeout 30000`.
4. Submit the protocol and complete original request with `herdr agent prompt`.
   Return immediately when `agent_prompted` is accepted. No `--wait`, work
   polling, focus command, retry, or task mutation occurs in the dispatcher.

Direct subprocess calls have deadlines: 15 seconds for pane inspection, tab
creation, and prompt acceptance; 35 seconds around Herdr's 30-second agent
startup deadline. The dispatcher never invokes a shell.

JSON-line output reports `allocated`, then `accepted`, or `error`. Events include
workspace, origin tab/pane, returned setup tab/pane, and agent name when known.
Exit zero means the setup prompt was accepted, **not** that setup or work finished.
Errors before tab creation have no allocation side effects. Errors during or
after creation leave the tab visible. A timeout can mean the server acted but the
response was lost: do not blindly redispatch. No automatic cleanup hides recovery
state. Partial valid handles are retained in errors when available.

## Environment And Model

Only the new tab receives these explicit overrides:

- `OPENCODE_CONFIG_CONTENT`: the native OpenCode 2 setup profile below, merged
  with inherited inline configuration. Other profiles, providers, permissions,
  and settings remain intact; the reserved setup profile is replaced. Because
  the full TUI has no `--agent` flag, this pane temporarily selects the profile
  with `default_agent`.
- `AGENCY_HERDR_WORKER_OPENCODE_CONFIG_CONTENT`: the normalized inherited inline
  configuration without the temporary profile or default. The setup helper
  applies it explicitly to the worker pane, so implementation workers retain
  their original `default_agent`, model, provider, and permission settings. An
  absent inherited config is represented as `{}`.
- `AGENCY_HERDR_ORIGIN_PANE_ID`: this dispatch's verified caller pane.
- `AGENCY_HERDR_ORIGIN_TAB_ID`: this dispatch's verified caller tab.
- `AGENCY_HERDR_ORIGIN_WORKSPACE_ID`: this dispatch's verified caller workspace.

Origin metadata is refreshed on each dispatch, not copied from stale origin
variables. It is for failure notifications, never a substitute for Herdr's own
`HERDR_*` IDs. Herdr assigns the new pane's actual caller IDs. The dispatcher does
not modify the caller's environment or global OpenCode settings.

Inherited `OPENCODE_CONFIG_CONTENT` accepts JSONC comments and trailing commas,
using `jsonc-parser` with the same parsing options as OpenCode. Every parse error
is rejected before executable checks or CLI calls; partially recovered objects
are never used. The resulting merged environment is serialized as ordinary JSON,
preserving settings and string values (not source comments or formatting). The
runtime dependency is declared in root `package.json` and `bun.lock`.

```json
{
	"$schema": "https://opencode.ai/config.json",
	"default_agent": "agency-herdr-dispatch-setup",
	"agents": {
		"agency-herdr-dispatch-setup": {
			"mode": "primary",
			"model": "openai/gpt-5.6-sol#low",
			"request": { "body": { "reasoningEffort": "low" } }
		}
	}
}
```

Low effort is a real model variant and request setting, not an instruction in
the prompt. OpenCode 2's full TUI has neither `--agent` nor `--model` flags, so
the temporary process uses the native `agents` map and a pane-local
`default_agent`. The model reference carries its variant as
`provider/model#variant`, and provider request settings live under
`request.body`. Subsequent `agency work` processes receive the saved inherited
inline config explicitly and do not inherit the temporary default.

Verified against the OpenCode 2 configuration and V1 migration documentation,
plus the isolated runtime smoke test in `test/opencode2-profile.test.ts`.
OpenCode 2 beta 0.0.0-beta-19296 resolves the exported profile to
`openai/gpt-5.6-sol`, variant `low`, with low reasoning effort. Injected-IO tests
verify that the helper restores inherited worker defaults before launch.
Provider credentials, model access, and plugins remain user-configured. A future
config/plugin/model change can invalidate these assumptions; no paid inference
or real agent launch was used to verify them.

## Setup Agent Protocol

The prompt delegates interpretation, minimal context lookup, and requested
noninteractive creation to the setup agent. For missing phase branch/path data,
it prescribes `agency phase show '<task-id>' '<phase-id>' --json`, then context by the
returned absolute document path. It includes direct task/phase/epic creation
recipes and prohibits broad source investigation, globs, and tool discovery.

An explicit new/separate/follow-up request creates a distinct item. Branch
ancestry is not a completion gate: basing a phase on another phase's branch must
not imply `--depends-on`. Explicit user gates and existing dependencies are
preserved unless the user explicitly asks to remove them.

The setup agent calls `agency-herdr-setup '<document-path>' --intent open|launch`
exactly once. That helper owns preparation, layout, launch, bounded startup
detection, final verification, and closing the setup pane on success. If selected,
the same quoted executable is forwarded via `--agency-executable`. Missing or
failed helpers leave recovery panes visible; no fallback transaction is invented.

The generated protocol requires every Bash tool call invoking the helper to set
the tool's `timeout` field explicitly to **1200000ms (20 minutes)**, rather than
the 120000ms default. This covers the whole helper transaction, including recovery,
final verification, notification, and cleanup. It is a maximum, not a delay or a
helper CLI flag. Creation, lookups, and user-authorized metadata modifications run
in separate calls with their own budgets. This does not increase the dispatcher's
own short subprocess deadlines or make the initiating agent poll.

Applying preparation defaults to 300000ms; context and dry-run stay at 120000ms,
and startup detection defaults to 60000ms. If explicitly changing the helper's
`--prepare-timeout-ms` or `--timeout-ms`, the caller budget must be at least
`1200000 + max(0, prepareTimeoutMs - 300000) + max(0, startupTimeoutMs - 60000)`.
Shell clients invoke the helper plainly without a shorter timeout wrapper. Do not
sleep, poll for the budget duration, or automatically retry on timeout. See
[setup limits](agency-herdr-setup.md#output-and-limits) for the conservative budget
sum, exact Bash tool arguments, and `spawnSync` signal/child-exit caveat.

Before the helper starts, an initial resolution/creation failure or inability to
invoke the helper requires one native toast, followed by stopping with the setup
pane visible. The prompt supplies this command with actual origin and setup IDs
(not the example IDs below), safely quoted:

```sh
herdr notification show "Agency setup failed" --body "Origin w3S:p47 (w3S:t20, w3S); setup w3S:p48 (w3S:t21, w3S). Initial resolution or creation failed before the helper started. See setup diagnostics; do not rerun blindly." --sound request
```

Do not retry a failed toast. It never focuses or sends input to the origin pane.
Once invoked, the helper owns its once-only failure notification using origin
metadata. The setup agent must not send another toast after a helper error,
including a cleanup error.

Successful setup includes closing the temporary pane, not just spawning a worker
and leaving an idle setup agent. Normally the helper closes it. Only if the helper
returns exit status zero to the still-open setup pane may the setup agent close
its own pane once. The helper's `complete` event alone is insufficient because
cleanup follows it. Any failure, including a cleanup error after worker launch,
leaves recovery panes visible: do not call the helper again or automatically close
the pane. Recovery requires explicit human authorization.

When the user explicitly wants to start now despite **existing working
dependencies**, the initiating agent may add `--allow-working-dependencies` to
dispatch. The setup prompt permits passing that same dedicated flag to the helper
only when the original request explicitly authorizes it. This is not inferred
from branch ancestry, a generic launch request, or dependency status. Without the
flag, the prompt forbids the override. Existing dependency declarations remain.
The setup agent records this invocation-specific approval in the item's Important
Decisions before launch so the worker can distinguish an expected preserved gate
from a new blocker, without re-requesting the same authorization. It is not a
standing override for later launches or other safety checks.
Never use `--force`. The helper flag is implemented separately; an older helper
must fail rather than silently bypass readiness.

## Verification

```sh
bun test test/agency-herdr-dispatch.test.ts
OPENCODE2_TEST_EXECUTABLE="$(command -v opencode2)" bun test test/opencode2-profile.test.ts
oxfmt --check bin/agency-herdr-dispatch.ts test/agency-herdr-dispatch.test.ts docs/agency-herdr-dispatch.md
bunx secretlint bin/agency-herdr-dispatch bin/agency-herdr-dispatch.ts test/agency-herdr-dispatch.test.ts docs/agency-herdr-dispatch.md
```

All dispatcher tests inject fake command and executable-validation IO; none invoke
real Herdr or Agency commands. An access-only test verifies that the entrypoint
is executable without launching it. Executable-selection tests cover validation
failures, safe quoting, helper propagation, gate preservation, and unchanged low
setup configuration/worker defaults.
Full Herdr response fixtures come from read-only inspection and historical CLI
responses, with names/caller fields and private paths/labels substituted. The
optional OpenCode 2 smoke test starts an isolated authenticated server with
temporary HOME/XDG directories. It confirms native profile discovery, low model
selection, and unchanged built-in worker settings without sending a model prompt.
JSONC tests preserve worker defaults and provider settings, comments inside
strings, and reject malformed partial parses.
