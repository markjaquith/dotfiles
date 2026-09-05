# Agency Herdr Setup

`agency-herdr-setup` is the deterministic half of the temporary setup-agent
handoff. The agent still interprets the complete user request and creates or
resolves the Agency item. It then invokes the helper **once**, from its temporary
Herdr pane:

```sh
agency-herdr-setup '/absolute/workbase/tasks/task-id/TASK.md' --intent launch
agency-herdr-setup '/absolute/workbase/tasks/task-id/phases/phase-id/PHASE.md' --intent open
```

The document path must be absolute and normalized. `--intent open|launch` is
required; there is no default. Options may precede or follow the one document
path. Duplicate options, missing values, and extra positional arguments fail.
An optional `--timeout-ms` sets the worker-detection deadline, default 60000,
range 1000 through 300000. There is no public or automatic `--force` option.
Tab labels come from the inspected Agency ID, or `taskId/phaseId` for a phase.

Two opt-in options support a single recovery invocation:

- `--allow-working-dependencies` is a Boolean switch with no value. It is forwarded
  once to preparation preview, preparation apply, and the pane-launched `work`
  command. Neither context, validation evidence, nor suggested contract commands
  can grant this permission. It is never inferred or enabled automatically.
- `--agency-executable /absolute/path/to/cli.ts` selects the Agency executable for
  **all** context, capability, preparation, and worker-launch calls. The path must
  be normalized, absolute, free of control characters, and not an option. Before
  any CLI invocation the helper checks that it resolves to a regular file and
  passes `fs.accessSync(..., X_OK)`. An executable Bun-shebang `cli.ts` is supported;
  a non-executable TypeScript source file is not. The default remains `agency`.

Use only a verified CLI in the managed task's writable checkout, not a separate
read-only development draft. This option changes no global installation, PATH,
configuration, or future helper default. It verifies file type and OS execute
permission, not code provenance, interpreter availability, or runtime behavior.
Subprocess paths remain argv elements; only pane-submitted shell text quotes the
selected executable, including embedded apostrophes. Default `agency work .`
and `agency work . --auto` text stays unchanged when neither option is present.

The helper requires `HERDR_ENV=1`, `HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, and
`HERDR_PANE_ID` inherited from the **temporary setup agent**, not the initiating
agent. IDs are opaque handles, not decimal counters; their exact workspace/tab/pane
relationships must match live metadata. Either
`AGENCY_SESSION_ID` or `AGENCY_TARGET` being set, even to an empty string, rejects
the invocation. Both must be absent from the environment. Do not override
these variables to make another pane appear to be the caller.

## Protocol

1. Inspect `agency context <document> --json`. Validate the target, document,
   authority, readiness, and expected paths. Unsupported modes, archived items,
   malformed identities, and invalid envelopes fail without UI changes.
2. Check the caller pane's live workspace and tab. Only with explicit
   `--allow-working-dependencies`, run the selected executable's `work prepare
--help` and `work --help`, each with a 15-second timeout. Both must exit zero
   and advertise the exact `--allow-working-dependencies` option at the start of
   a help line, followed by whitespace or end of line. Prose mentions, suffixes,
   `=true`, stderr-only output, and nonzero exits do not qualify. These read-only
   checks precede UI mutations. Then rename the explicit setup tab. An unsupported
   capability retains the recovery layout but skips all preparation and worker
   launch. Default invocations make **no capability calls**.
3. Require clean initial validation and nonterminal work. For execution tasks and
   phases, let unforced preparation with `--dry-run --json` decide readiness,
   including valid `working` resumption. Validate its execution contract and pass its exact
   `validationEvidence.evidence` object as inline JSON to applying preparation
   with `--evidence`. Require unchanged, reused evidence in the applying result.
   Epic and multi-phase task orchestration skips preparation and accepts readiness
   or aggregate status `working` with no validation blockers, matching installed
   `ReadinessService.isResumableWork`. Other non-validation blockers do not prevent
   that installed resumption path; unforced `agency work` checks it again.
4. Split the setup pane down into a worker shell using the authoritative item
   directory and `--no-focus`. If preflight or preparation failed, leave this
   shell unlaunched. Otherwise submit `agency work .`, adding `--auto` only for
   `launch`, and the explicit readiness switch when requested. Preparation and
   launch never receive `--force`.
5. Split the worker pane right, also with explicit cwd and `--no-focus`, and
   submit `nvim -- 'TASK.md'`, `PHASE.md`, or `EPIC.md`. This happens **before**
   worker detection, including after preparation or launch failures.
6. If launched, wait on the explicit worker pane for `idle|done` (`open`) or
   `working|done` (`launch`). Also wait for `blocked` so it fails immediately and
   stays visible. Only the installed Herdr `agent_not_found` startup race is
   retried, at 100ms intervals within the same deadline. Unknown state cannot
   satisfy the wait; timeout, disappearance, malformed output, and transport
   failures retain the setup pane.
7. Make exactly one final `agency context <document> --json` call after a trusted
   initial inspection, even after preparation, layout, launch, or wait failure.
   Check validation and compare target identity, workbase root, and full authority
   against the initial context. Final workspace warnings must be empty. Legitimate
   status/revision changes, including rapid completion to `done` or `dropped`, are
   allowed; only the initial check prohibits terminal work. A launched execution workspace must also be
   completely materialized with its writable checkout registered.
8. Only when every step succeeds, synchronously print completion and returned
   IDs, then close the explicit setup pane. Closing may terminate the helper
   before it returns. No success depends on reading output after that close.

An initial command/identity failure has no trusted target or recovery directory,
so it stops immediately without a final verification. A caller-pane or rename
failure retains the pane and still performs final verification; it does not
attempt further UI mutations with an untrusted location. A failed worker split
cannot create the editor subtree. No failed step is retried by rerunning the
whole helper: that would create duplicate panes. Use the emitted IDs for manual
recovery.

## No Force

Automatic force is disabled under the installed Agency contract. Its `--force`
overrides validation **and active worktree locks**, even during dry-run preparation.
There is no safe readiness-only override in the installed **3.2.15** contract:
neither `agency work prepare --help` nor `agency work --help` advertises
`--allow-working-dependencies`. Explicit opt-in therefore fails closed on that
version, before preparation or worker launch, with an error naming the executable
and unsupported help commands. Use a verified supporting managed CLI via
`--agency-executable`, or wait for a release. Help advertisement is a capability
gate, not proof of the upstream implementation's safety. The selected CLI remains
responsible for readiness and active-lock enforcement. An unforced preflight
refusal, including an open item blocked by working dependencies, builds the
unlaunched recovery layout and reports: "Requires readiness-only override;
--force also overrides active locks." It is never retried with an override.
Upstream error text may suggest force; the helper does not follow that suggestion.
When supported, explicit permission is supplied independently on preview, apply,
and launch; the exact validated evidence is still forwarded and must be reused
unchanged. Suggested commands in an execution contract are not executed.

All context validation warnings fail closed. Initial workspace inspection allows
only the exact unresolved **declared writable branch or base** warning for the
declared repository. These are provisional: unforced preparation must check and
resolve them, including remote base availability/fetch. Reference warnings,
different branches/bases/repositories, and all other inspection warnings remain
prohibited. Final workspace warnings must be fully empty, including branch/base
warnings that were provisionally accepted initially.

## Output And Limits

Output is JSON Lines: `command`, `diagnostic`, `error`, and pre-close `complete` events, with
available target/workspace/tab/setup/worker/editor IDs. Failure returns status 1
and retains the setup pane. Command failures include captured stdout/stderr;
evidence is omitted from command progress to keep it readable. Preparation and
context subprocesses have 120-second limits, ordinary Herdr calls 15 seconds,
and detection calls use the remaining detection budget. Timed-out child CLI
processes receive the subprocess runner's termination signal; the helper never
issues process-kill commands or stops the worker or Herdr server.

### Failure Notification

The dispatcher supplies `AGENCY_HERDR_ORIGIN_PANE_ID`,
`AGENCY_HERDR_ORIGIN_TAB_ID`, and `AGENCY_HERDR_ORIGIN_WORKSPACE_ID` for the initiating
pane, separately from the setup pane's inherited `HERDR_*` identity. On failure,
one final best-effort handler verifies that origin with `herdr pane get <origin>`
in the inherited Herdr session. Exact live pane/tab/workspace metadata must match,
the origin workspace must match the setup workspace when available, and origin pane/tab must
differ from setup. Opaque IDs remain valid. Missing, stale, or mismatched origin
metadata prevents notification and emits a diagnostic.

After successful origin verification, the helper attempts exactly one:

```sh
herdr notification show 'Agency setup failed' --body '<origin and failed setup IDs; concise error>' --sound request
```

The CLI has **no notification target option**. This is a session toast identifying
the origin and failed setup pane/tab/workspace, not a message delivered into that
agent's context or a durable state update in its pane. Full errors and returned
worker/editor IDs stay in the setup pane's JSON Lines output. There is no prompt,
input, send-text, send-keys, focus, or notification retry. An initiating busy agent
cannot automatically consume this report through the installed toast-only CLI.
Notification transport/validation failures emit a diagnostic without replacing
the original error or exit status. Successful notification emits
`failure-notification`. The `notification_show` response must report `shown: true`
and `reason: shown`; disabled notifications, rate limits, no foreground client,
and a busy client are diagnostic failures, not successful delivery, and are not
retried. This includes early argument, environment, initial-context,
and executable-validation failures when the supplied origin can be verified, and
late final-verification or close failures. Success and direct invocations without
origin metadata make no notification or origin-verification calls.

Item creation happens before the helper. Creation failures must be reported by
the dispatcher's setup-agent prompt; the helper cannot observe or report them.

This helper creates no items, tabs, or workspaces, never focuses UI, never edits
plans, and never stages or commits. It is agent-independent: OpenCode and Pi
setup agents can invoke the same helper. The extensionless Bun entrypoint imports
the adjacent TypeScript implementation, with no added dependency.

### Contract Caveats

- Contracts were inspected in installed Agency **3.2.15** and Herdr **0.8.2**
  help/source. Relevant Agency sources are `src/protocol.ts`,
  `src/services/ContextService.ts`, `src/services/ReadinessService.ts`,
  `src/services/GraphService.ts`, `src/services/WorktreeLock.ts`, `src/commands/work.ts`, and
  `src/workbase/execution-contract.ts`. Herdr sources are `src/cli/pane.rs`,
  `src/cli/agent.rs`, `src/api/wait.rs`, and `src/api/schema/`.
- Evidence reuse and dynamic safety checks are upstream operations, not an atomic lock held by this
  helper. A concurrent edit can invalidate evidence between preview and apply;
  the helper rejects the changed applying result, but cannot undo materialization
  that already happened. Similarly, authority can change between apply and the
  pane-submitted launch; final verification detects this but cannot retroactively
  prevent the launch. Eliminating those races requires an upstream atomic guarded
  prepare/launch contract, not additional speculative shell commands.
- `pane run` acknowledges input submission, not successful Neovim initialization.
  Herdr's `pane run` and `pane close` deliberately return no output on success;
  exit status zero with empty stdout/stderr is accepted for those commands only.
  Structured reads still require valid JSON, and empty nonzero responses fail.
  Worker detection checks the expected Herdr lifecycle, not task completion or
  proof that `--auto` delivered a particular prompt. An `open` worker may be
  `done` because its unfocused idle tab has not been seen.
- Tests use only injected fake subprocesses and a fake clock. No real Agency
  mutation or Herdr pane control was exercised. Shell startup timing, installed
  editor behavior, and self-close delivery still require an explicitly authorized
  live smoke test.

## Verification

```sh
bun test test/agency-herdr-setup.test.ts
bunx tsc --noEmit -p tsconfig.json
oxfmt --check bin/agency-herdr-setup.ts test/agency-herdr-setup.test.ts docs/agency-herdr-setup.md
bunx secretlint bin/agency-herdr-setup.ts test/agency-herdr-setup.test.ts docs/agency-herdr-setup.md
```

The test runtime records every argv/cwd/timeout and never calls Agency or Herdr.
Tests cover execution and orchestration routing, both intents, evidence reuse,
the absence of force on every recorded command, recovery ordering, bounded
recognition, working resumption, rapid completion, provisional warning boundaries,
final validation and authority changes, empty Agency environment variables,
malformed data/IDs, and paths containing spaces and quotes.
They also verify actual executable file permissions using temporary fixtures,
shell-word parsing without execution, exact help capability matching, explicit
permission forwarding independent of evidence/contract suggestions, and once-only
notification with no wrong-origin delivery or terminal input. The entrypoint
subprocess test clears inherited origin metadata to prevent live notifications.
Optional `AGENCY_HERDR_LIVE_CONTRACT=1` tests read installed Agency help and caller
pane metadata only; all preparation, pane mutations, and notifications stay mocked.
