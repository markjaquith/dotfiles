---
name: herdr
description: Control Herdr from inside it. Use when running inside Herdr (`HERDR_ENV=1`) to inspect workspaces, tabs, panes, sibling agents, run commands in panes, read output, or wait for state changes via the `herdr` CLI.
---

# Herdr Agent Skill

Before using this skill, check that `HERDR_ENV=1`. If it is not set to `1`, say you are not running inside a Herdr-managed pane and stop. Do not inspect or control a focused Herdr pane from outside Herdr.

Herdr is a terminal-native agent multiplexer. It gives you workspaces, tabs, and panes. Each pane is a real terminal with its own shell, agent, server, or log stream, and the `herdr` CLI talks to the running Herdr instance over a local Unix socket.

Use this skill to:

- See what other panes and agents are doing.
- Create tabs for separate subcontexts inside one workspace.
- Split panes and run commands in them.
- Start servers, watch logs, and run tests in sibling panes.
- Wait for specific output before continuing.
- Wait for another agent to finish.
- Spawn more agent instances.

If you need the raw protocol or full API reference, read the Herdr socket API docs: <https://herdr.dev/docs/socket-api/>.

## Concepts

Workspaces are project contexts. Each workspace has one or more tabs. Unless manually renamed, a workspace's label follows the first tab's root pane, usually the repo name or the root pane's current folder name.

Tabs are subcontexts inside a workspace. Each tab has one or more panes.

Panes are terminal splits inside a tab. Each pane runs its own process: a shell, an agent, a server, or anything else.

Agent status is detected automatically by Herdr. The API exposes one public field:

- `agent_status`: `idle`, `working`, `blocked`, `done`, or `unknown`

`done` means the agent finished, but you have not looked at that finished pane yet.

Plain shells still exist as panes, but Herdr's sidebar agent section intentionally focuses on detected agents rather than listing every shell.

IDs are compact public IDs for the current live session:

- Workspace IDs look like `1`, `2`.
- Tab IDs look like `1:1`, `1:2`, `2:1`.
- Pane IDs look like `1-1`, `1-2`, `2-1`.

IDs can compact when tabs, panes, or workspaces are closed. Do not treat them as durable IDs. Re-read IDs from `workspace list`, `tab list`, `pane list`, or create and split responses when you need a current ID.

## Discovery

See what panes exist and which one is focused:

```bash
herdr pane list
```

The focused pane is yours. Other panes are neighbors.

List workspaces:

```bash
herdr workspace list
```

List tabs in the current workspace:

```bash
herdr tab list --workspace 1
```

## Tab Management

Create a new tab:

```bash
herdr tab create --workspace 1
```

Create and name it in one step:

```bash
herdr tab create --workspace 1 --label "logs"
```

Rename a tab:

```bash
herdr tab rename 1:2 "logs"
```

Focus a tab:

```bash
herdr tab focus 1:2
```

Close a tab:

```bash
herdr tab close 1:2
```

## Read Another Pane

See what is on another pane's screen:

```bash
herdr pane read 1-1 --source recent --lines 50
```

Sources:

- `--source visible`: current viewport
- `--source recent`: recent scrollback as rendered in the pane
- `--source recent-unwrapped`: recent terminal text with soft wraps joined back together

## Split A Pane And Run A Command

Split your pane to the right and keep focus on your current pane:

```bash
herdr pane split 1-2 --direction right --no-focus
```

That prints JSON with the new pane nested at `result.pane.pane_id`. Parse that value, then run a command in that pane:

```bash
NEW_PANE=$(herdr pane split 1-2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
```

Split downward instead:

```bash
herdr pane split 1-2 --direction down --no-focus
```

## Wait For Output

Block until specific text appears in a pane. This is useful for waiting on servers, builds, and tests.

For `--source recent`, matching uses unwrapped recent terminal text, so pane width and soft wrapping do not break matches. `pane read --source recent` still shows the pane as rendered. To inspect the same transcript the waiter matches, use `pane read --source recent-unwrapped`.

```bash
herdr wait output 1-3 --match "ready on port 3000" --timeout 30000
```

With regex:

```bash
herdr wait output 1-3 --match "server.*ready" --regex --timeout 30000
```

If it times out, exit code is `1`.

## Wait For An Agent Status

Block until another agent reaches a specific status:

```bash
herdr wait agent-status 1-1 --status done --timeout 60000
```

Use this when you want the same `done` and `idle` distinction the UI shows.

## Send Text Or Keys To A Pane

Send text without pressing Enter:

```bash
herdr pane send-text 1-1 "hello from opencode"
```

Press Enter or other keys:

```bash
herdr pane send-keys 1-1 Enter
```

`pane run` sends the text and then a real Enter key in one request:

```bash
herdr pane run 1-1 "echo hello"
```

## Workspace Management

Create a new workspace:

```bash
herdr workspace create --cwd /path/to/project
```

Create and name one in one step:

```bash
herdr workspace create --cwd /path/to/project --label "api server"
```

Create one without focusing it:

```bash
herdr workspace create --no-focus
```

Focus a workspace:

```bash
herdr workspace focus 2
```

Rename a workspace:

```bash
herdr workspace rename 1 "api server"
```

Close a workspace:

```bash
herdr workspace close 2
```

Close a pane:

```bash
herdr pane close 1-3
```

## Recipes

Run a server and wait until it is ready:

```bash
NEW_PANE=$(herdr pane split 1-2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
herdr wait output "$NEW_PANE" --match "ready" --timeout 30000
herdr pane read "$NEW_PANE" --source recent --lines 20
```

Run tests in a separate pane and inspect the result:

```bash
NEW_PANE=$(herdr pane split 1-2 --direction down --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "cargo test"
herdr wait output "$NEW_PANE" --match "test result" --timeout 60000
herdr pane read "$NEW_PANE" --source recent --lines 30
```

Check what another agent is working on:

```bash
herdr pane list
herdr pane read 1-1 --source recent --lines 80
```

Watch another pane robustly:

```bash
herdr pane read 1-3 --source recent --lines 40
herdr wait output 1-3 --match "ready" --timeout 30000
herdr pane read 1-3 --source recent-unwrapped --lines 40
```

Spawn a new agent and give it a task:

```bash
NEW_PANE=$(herdr pane split 1-2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "opencode"
herdr wait output "$NEW_PANE" --match ">" --timeout 15000
herdr pane run "$NEW_PANE" "review the test coverage in src/api/"
```

Coordinate with another agent:

```bash
herdr wait agent-status 1-1 --status done --timeout 120000
herdr pane read 1-1 --source recent --lines 100
```

## Notes

- `workspace list`, `workspace create`, `tab list`, `tab create`, `tab get`, `tab focus`, `tab rename`, `tab close`, `pane list`, `pane get`, `pane split`, `wait output`, and `wait agent-status` print JSON on success.
- `pane read` prints text, not JSON.
- `pane read --format ansi` or `pane read --ansi` returns a rendered ANSI snapshot for TUI feedback loops.
- `pane read --source recent-unwrapped` is useful when you want to inspect the same unwrapped transcript that `wait output --source recent` matches against.
- `pane send-text`, `pane send-keys`, and `pane run` print nothing on success.
- Parse IDs from `workspace create`, `tab create`, and `pane split` responses when you need new IDs.
- `workspace create` returns `result.workspace`, `result.tab`, and `result.root_pane`.
- `tab create` returns `result.tab` and `result.root_pane`.
- For `pane split`, the new pane ID is at `result.pane.pane_id`.
- Use `pane read` for current output that already exists. Use `wait output` for future output you expect next.
- `--no-focus` on split, tab create, and workspace create keeps your current terminal context focused.
- Without `--label`, workspace create keeps cwd-based naming and tab create keeps numbered naming.
- `--label` on tab create and workspace create applies the custom name immediately.
- If you are running inside Herdr, the `HERDR_ENV` environment variable is set to `1`.
