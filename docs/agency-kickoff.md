# Agency Kickoff

`agency-kickoff` opens or launches an Agency item in a new Herdr tab with one
deterministic command. It replaced the earlier `agency-herdr-dispatch` /
`agency-herdr-setup` pair, which started a temporary OpenCode setup agent to
interpret the request.

```sh
agency-kickoff task-id                  # agency work . --auto
agency-kickoff task-id/phase-id --open  # agency work .
agency-kickoff epic:epic-id
agency-kickoff CAN-1234                 # or a ticket URL
agency-kickoff tasks/task-id            # or a document path
```

Options:

- `--open`: run `agency work .` without `--auto`.
- `--allow-working-dependencies`: forwarded to the preflight and to `agency work`.
  Only for explicit user authorization. Never substitute `--force`.
- `--workbase <selector>`: forwarded to Agency when not running inside a workbase.
- `--agency-executable <absolute-path>`: use a specific Agency CLI for every
  command in this run, including the worker pane.

Requires `HERDR_ENV=1` and `HERDR_WORKSPACE_ID`. Works the same from OpenCode, Pi,
or a plain shell.

## Steps

1. **Resolve.** Existing paths use `agency context <path>`. `epic:<id>` and
   `task/phase` use `--epic` / `--task --phase`. Ticket URLs match
   `agency task list` entries by ID (`KEY` or `KEY-slug`) or `ticketUrl`. Other
   targets try `agency context <id>` first; ticket-shaped IDs that do not exist
   fall back to ticket matching. Zero or multiple ticket matches fail.
2. **Preflight.** Rejects archived, terminal, invalid, and self-launch targets
   (`AGENCY_TARGET`). Execution and review units run
   `agency work prepare <dir> --dry-run --json` and fail on validation issues or
   workspace warnings. Epics and multi-phase tasks must be ready or working.
3. **Tab.** `herdr tab create --no-focus`, labeled with the target ID, cwd set to
   the item directory. The root pane is the worker (left).
4. **Editor.** Split right and run `nvim -- TASK.md` (or `PHASE.md`/`EPIC.md`).
5. **Worker.** Run `agency work . [--auto]`. `agency work` materializes the
   checkout and claims the unit. If it exits non-zero, Herdr shows an
   "Agency launch failed" toast and the pane keeps the error visible.

Every failure in steps 1–2 happens before a tab exists. The command prints one
JSON line, `{"event":"launched",...}` or `{"event":"error","stage":...}`,
including tab and pane IDs once known, and exits 0 or 1. It never waits for the
worker, focuses the tab, or retries.

The caller's `OPENCODE_CONFIG_CONTENT`, if set, is passed to both panes.

## Verification

```sh
bun test test/agency-kickoff.test.ts
oxfmt --check bin/agency-kickoff.ts test/agency-kickoff.test.ts docs/agency-kickoff.md
```

The tests inject a fake runtime; no real Agency or Herdr command runs.
