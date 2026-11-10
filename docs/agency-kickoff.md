# Agency Kickoff

`agency-kickoff` opens or launches an Agency item in a new Herdr or Rex tab with
one deterministic command. It replaced the earlier `agency-herdr-dispatch` /
`agency-herdr-setup` pair, which started a temporary OpenCode setup agent to
interpret the request.

```sh
agency-kickoff task-id                  # agency work . --auto
agency-kickoff task-id/phase-id --open  # agency work .
agency-kickoff epic:epic-id
agency-kickoff ABC-1234                 # or a ticket URL
agency-kickoff tasks/task-id            # or a document path
```

Options:

- `--open`: run `agency work .` without `--auto`.
- `--allow-working-dependencies`: forwarded to the preflight and to `agency work`.
  Only for explicit user authorization. Never substitute `--force`.
- `--workbase <selector>`: forwarded to Agency when not running inside a workbase.
- `--agency-executable <absolute-path>`: use a specific Agency CLI for every
  command in this run, including the worker pane.
- `--mux herdr|rex`: choose the multiplexer instead of detecting it.

## Multiplexer

| Detected when                          | Tab goes into                                      |
| -------------------------------------- | -------------------------------------------------- |
| `HERDR_ENV=1` (wins when both are set) | the current Herdr workspace (`HERDR_WORKSPACE_ID`) |
| `REX_SESSION` is set                   | the current Rex session                            |

A Herdr pane inside a Rex terminal sees both variables; the innermost
multiplexer, Herdr, wins. Works the same from OpenCode, Pi, or a plain shell.

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
3. **Tab.** An unfocused tab labeled with the target ID, cwd set to the item
   directory: the worker on the left, an editor on the right running
   `nvim -- TASK.md` (or `PHASE.md`/`EPIC.md`).
4. **Worker.** Runs `agency work . [--auto]`. `agency work` materializes the
   checkout and claims the unit. If it exits non-zero, a desktop notification
   says "Agency launch failed" and the pane keeps the error visible.

### Herdr

`herdr tab create --no-focus`, `herdr pane split --direction right --no-focus`,
then `herdr pane run` in each pane. Failures use `herdr notification show`. A
failure after the tab exists leaves it visible and reports its IDs.

### Rex

One `rex api call session.new_window` with `focus: false` and a horizontal split
layout. Rex creates the whole tab or nothing, so there is no partial tab to
recover. Both panes are login shells whose `initial_input` types the command, so
they remain usable shells afterwards. Failures print an OSC 777 desktop
notification, which needs Rex's Settings > Notifications > Terminal
notifications. Rex blocks have no environment option, so
`OPENCODE_CONFIG_CONTENT` is passed by starting the shell through
`/usr/bin/env`. Agentodon may add its sidebar to the new tab; the result's pane
IDs are the worker and editor, not the sidebar.

## Output

Every failure in steps 1–2 happens before a tab exists. The command prints one
JSON line, `{"event":"launched",...}` or `{"event":"error","stage":...}`, with
`mux`, `workspaceId` (Herdr) or `sessionId` (Rex), and `tabId`, `workerPaneId`,
and `editorPaneId` once known. It exits 0 or 1. It never waits for the worker,
focuses the tab, or retries.

The caller's `OPENCODE_CONFIG_CONTENT`, if set, is passed to both panes.

## Verification

```sh
bun test test/agency-kickoff.test.ts
oxfmt --check bin/agency-kickoff.ts test/agency-kickoff.test.ts docs/agency-kickoff.md
```

The tests inject a fake runtime; no real Agency, Herdr, or Rex command runs.
