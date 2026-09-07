# OpenCode 2 Rollout

The `opencode2` branch is rebased onto main. At the user's request, OpenCode 2
`0.0.0-beta-19228` is installed globally and `opencode` links to `opencode2` in
Bun's global bin directory. The OpenCode 1 executable has been removed; sessions,
credentials, and configuration are preserved. The installer maintains this setup.

The legacy continuation wrapper and binary PATH entry are removed. `occ` now
uses native OpenCode 2 continuation; equivalent directory-scoped behavior remains
to be checked. Shell and Agency mini launches use the `mini` subcommand. This
activation does not imply the remaining integration gates have passed.

## Setup Profile Discovery: Verified

On September 7, 2026, isolated runtime tests passed against both published builds:

- `@next`: `0.0.0-beta-17823`
- `@beta`: `0.0.0-beta-19228`

The earlier empty `/api/agent` results were premature readiness checks. A new
server can accept requests before its agent registry is populated; the older
build also returned a transient HTTP 503 during startup. Repeated reads against
the same server load the built-ins and the inline Agency setup profile.

The opt-in smoke test imports the dispatcher's actual `setupConfig` and verifies
the setup profile's primary mode, model, and low variant, while the build agent
retains its default model/settings. It uses a temporary HOME and XDG directories,
an isolated authenticated loopback server, and no inherited provider credentials.
It sends no model prompts, and terminates the server and removes temporary state.

```sh
OPENCODE2_TEST_EXECUTABLE=/absolute/path/to/opencode2 \
  bun test test/opencode2-profile.test.ts
```

Without that environment variable, the test is skipped. It does not install or
select an OpenCode version. Readiness checks must wait for the requested profile
within a bounded deadline, not assume a listening socket or first response means
initialization has completed.

## Remaining Gates

- The user confirmed mini profile selection works. Shared-service isolation and
  Herdr state reporting in mini remain unverified; mini does not run TUI plugins.
  The user accepted the mini reporting limitation for this rollout.
- Preserve directory-scoped continuation without the removed `session list`
  command or unverified assumptions about preview database paths.
- Validate end-to-end shell/automation behavior with the pinned global runtime.

## Plugin Migration

The local plugin manifest and npm lock now pin `@opencode-ai/plugin` to
`0.0.0-beta-19228`, matching the CLI. The manifest is no longer ignored. The
OpenCode installer and CI run `npm ci --ignore-scripts` for this subproject.
The dependency installation reports 11 moderate transitive audit findings;
no forced dependency upgrades were applied to this version-sensitive beta SDK.

The six retained server plugins now use `Plugin.define`, setup contexts, and
domain hooks rather than the unavailable `/v1` imports:

- PR merge guard, preserving the Agency/Topo allowlist.
- Safe-trash rewriting, preserving its existing behavior.
- `blockNpm`, still intentionally a no-op.
- Completion/attention sounds, preserving existing environment opt-ins.
- `/keep-going`, with cleanup and duplicate-replay protection.
- Worktrunk activity markers.

The obsolete test importing the intentionally deleted jj plugin is removed.
The jj shell helper and its tests remain. Typechecking and focused adapter tests
pass. Hook tests validate argument mutation and rejection with mocked execution;
the real-host API has no tool-execution endpoint, so those tests do not establish
end-to-end enforcement during an actual model tool call.

```sh
OPENCODE2_TEST_EXECUTABLE=/absolute/path/to/opencode2 \
  bun test test/opencode2-profile.test.ts test/opencode2-plugins.test.ts
```

The host smoke test confirms all six server plugins are active and `/keep-going`
is registered, without submitting prompts. Sound playback still requires the
existing worker-role gate or `OPENCODE_DING=1`; the new shared-service default
does not establish pane-local sound behavior.

## Herdr Adapter

`cli.json` registers the `beta-adapters/herdr` directory. Its TUI entrypoint
adapts beta routes/events to Herdr's existing socket protocol, filters events to
the selected root and its descendants, and cleans up listeners/polling.
Unix-socket tests cover root/child isolation, selection changes, retries, and
cleanup. Full interactive host validation remains outstanding.

The managed v11 state reporter is preserved byte-for-byte under
`legacy-integrations/`, outside server autodiscovery. The original managed TUI
reporter is reused through a facade. Do not reinstall the old Herdr integration
without reconciliation: it can recreate `plugins/herdr-agent-state.js`. The
OpenCode installer fails explicitly if that legacy path reappears rather than
silently overwriting or enabling it. A shared server must not report another
pane's session using its inherited Herdr environment.

## Unsupported Behavior

- The custom paste threshold is archived as
  `legacy-integrations/paste-summary-threshold.ts.disabled`. This beta exposes
  only native compact/full paste display, not the old composer KV control or
  configurable 10-line/2,048-character threshold. Native behavior remains in use;
  the old, inactive `tui.json` registration is removed. The user acknowledged
  this limitation for the rollout.
- `opencode-queue` versions `0.11.2` and current latest `0.13.2` both fail actual
  host activation because they export a legacy hook function. Its registration
  is removed. The user confirmed this plugin is unnecessary for v2; no parity
  work is planned.
- Plannotator is pinned to `0.27.12`, verified active in an isolated beta host
  with its review/annotation commands registered. Browser review, approval, and
  plan-submission flows have not been exercised.

Restart OpenCode clients and the shared service when ready to load the changed
plugins. The existing running session is not evidence of newly loaded behavior.
