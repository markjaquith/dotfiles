---
name: tmux-debugging
description: Use when changing tmux config or using tmux to debug something.
---

## Purpose

Use this skill to diagnose tmux behavior in a live development environment while preserving active sessions and panes.

## Critical Safety Rule

Never kill the tmux server without asking the user first.

This includes commands such as:

```bash
tmux kill-server
pkill tmux
killall tmux
```

Prefer targeted, reversible inspection and reload commands. If a destructive command might be needed, explain the risk and ask for explicit confirmation before running it.

## When To Use

Invoke this skill when the user mentions any of the following:

- tmux configuration, bindings, panes, windows, sessions, or status line behavior
- `~/.config/tmux/tmux.conf`, TPM, tmux plugins, or tmux reload failures
- pane capture, window naming, session selection, or shell integration issues
- OpenCode, Neovim, zsh, or worktree behavior that depends on tmux

## Default Workflow

1. Confirm whether the current shell is inside tmux by checking `$TMUX` or using `tmux display-message -p`.
2. Inspect live state with read-only commands such as `tmux list-sessions`, `tmux list-windows`, `tmux list-panes -a`, and `tmux show-options -g`.
3. Read the relevant repo files before editing behavior, especially `.config/tmux/tmux.conf` and related scripts under `.zsh/`, `bin/`, or `.config/opencode/`.
4. Prefer reloading config with `tmux source-file ~/.config/tmux/tmux.conf` over restarting tmux.
5. If changing repo files, run the narrowest relevant syntax or formatting checks for those files.

## Safe Debugging Practices

- Treat tmux as live user state, not a disposable test process.
- Avoid commands that close panes, windows, sessions, or the server unless the user explicitly asks for that outcome.
- If cleanup is necessary, prefer targeting a known test session with `tmux kill-session -t <name>` after confirming it is safe.
- Capture diagnostics before changing configuration so behavior can be compared after reload.
- Preserve existing key bindings and plugin order unless the bug requires changing them.

## Failure Modes To Avoid

- Running `tmux kill-server` without explicit user approval
- Restarting tmux to test a config change when `source-file` is sufficient
- Killing an attached session while the user may be working in it
- Assuming tmux plugin problems require deleting plugin directories before inspecting TPM state
- Editing shell integration without checking whether the behavior comes from `.zsh/015-tmux.zsh`, `.zshrc`, `.config/tmux/tmux.conf`, or a plugin
