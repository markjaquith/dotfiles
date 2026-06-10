---
name: tmux-control
description: Use when asked to control or get information about, or send commands to, other tmux windows.
---

## Purpose

Use this skill to quickly inspect and control other tmux windows in the current session, especially when coordinating commands across other OpenCode instances.

Favor tmux's own live pane and window metadata over slower process-tree inspection. Keep discovery commands short to reduce TOCTOU exposure.

## Safety Rules

Never kill panes, windows, sessions, or the tmux server unless the user explicitly asks for that destructive action.

Prefer read-only tmux commands for discovery:

- `tmux display-message -p`
- `tmux list-windows`
- `tmux list-panes`
- `tmux display-panes`

When sending input to another pane, target pane ids such as `%93`, not window names. Window names can change and are not unique.

## Find Other OpenCode Windows

Use this fast two-call pattern to find OpenCode panes in the current tmux session while excluding the window that the current OpenCode instance is running in:

```zsh
cur=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}')
tmux list-panes -s -f "#{&&:#{!=:#{window_id},$cur},#{m:*opencode*,#{pane_current_command}}}" -F '#{window_id} #{window_index} #{window_name} #{pane_id} #{pane_current_command}'
```

This intentionally matches `*opencode*` because OpenCode may appear as `opencode`, `opencode.exe`, or a similar wrapper command.

Example output:

```text
@92 2 OpenCode 2 %93 opencode.exe
```

Interpretation:

- `@92` is the tmux window id.
- `2` is the tmux window index.
- `OpenCode 2` is the current tmux window name.
- `%93` is the pane id to target with commands.
- `opencode.exe` is the foreground command in that pane.

## Faster But Less Exact Exclusion

If the current OpenCode window is known to be the active tmux window, this single tmux command excludes the active window:

```zsh
tmux list-panes -s -f '#{&&:#{==:#{window_active},0},#{m:*opencode*,#{pane_current_command}}}' -F '#{window_id} #{window_index} #{window_name} #{pane_id} #{pane_current_command}'
```

Prefer the exact `window_id` exclusion when correctness matters. Use the `window_active` form only when speed and brevity are more important and the active-window assumption is safe.

## Send A Command To Other OpenCode Panes

Discover target pane ids first, then send literal input followed by Enter:

```zsh
cur=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}')
targets=("${(@f)$(tmux list-panes -s -f "#{&&:#{!=:#{window_id},$cur},#{m:*opencode*,#{pane_current_command}}}" -F '#{pane_id}')}")

for pane in "${targets[@]}"; do
	tmux send-keys -t "$pane" -l -- "$message"
	tmux send-keys -t "$pane" Enter
done
```

Use `send-keys -l` for user-provided text so tmux sends it literally instead of interpreting special key names.

## Workflow

1. Confirm the command is running inside tmux by checking `$TMUX` or `$TMUX_PANE`.
2. Capture the current window id with `tmux display-message -p -t "$TMUX_PANE" '#{window_id}'`.
3. Use `tmux list-panes -s` to inspect only the current session.
4. Filter out the current window id.
5. Filter for `pane_current_command` matching `*opencode*`.
6. Use pane ids from the result for any follow-up `tmux send-keys` calls.

## Failure Modes To Avoid

- Do not identify OpenCode panes by window name alone.
- Do not target windows by index when pane ids are available.
- Do not use process-tree inspection first; it is slower and more race-prone.
- Do not include the current OpenCode window when broadcasting commands.
- Do not send text without `send-keys -l` when the text may contain spaces, punctuation, or key-like words.
