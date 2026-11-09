# Herdr-app preferences

Use `home/.config/ghostty/config` as the reference for terminal appearance and
behavior, except for the explicitly requested Herdr navigation shortcuts:
Ctrl-h/j/k/l navigate panes; Option-h/l switch tabs.

`home/.config/herdr-app/` contains personal config, synced with `dotfiles`.
Keep generated app files and session state local.

## Ghostty parity

- MonoLisa (Herdr renders normal terminal text at Medium weight).
- Effective terminal font size 14: `font_size` 15.555556 × existing UI `zoom` 0.9.
  Herdr's zoom scales the entire app, unlike Ghostty's font-size controls.
- Programming ligatures enabled, matching Ghostty's default font features.
- Catppuccin Macchiato background, foreground, selection, cursor and ANSI palette
  copied from Ghostty's effective config. This is a snapshot, not an automatic import.
- Shift-Enter sends `ESC [13;2u`, matching the explicit Ghostty binding.
- Option-as-Alt remains automatic, as in Ghostty.

## Agent chooser (Cmd-O)

`mods/agent-chooser/` is a personal, native floating dialog, opened/toggled by
Cmd-O. It does not change the Ghostty binding or the regular Herdr plugin.

- Attention shows blocked/done agents, newest state changes first.
- Working shows working agents; All includes idle agents too.
- Opens on Attention when nonempty, otherwise Working, otherwise All.
- Type to fuzzy-filter by space, tab, agent, title, status or terminal address.
- Up/Down or Ctrl-N/P select; Tab/Shift-Tab cycle views; Enter focuses the agent.
- Esc, Ctrl-C or Cmd-O dismiss without changing terminals. Clicking a row goes
  to that agent; the view tabs and Close control also work with the mouse.
- Uses Herdr-app’s live data (no subprocesses or polling); preserves selection
  by terminal address as agents reorder or change state.
- The `mod:agent-chooser > Input` key section compiles to the scoped GPUI
  context `mod == agent-chooser > Input`. This intentionally matches the
  native input itself, taking priority over its built-in arrow/Tab actions
  without overriding other inputs or terminal keys.

Verify with `bun test test/herdr-app-agent-chooser.test.js` and
`herdr-app check ~/.config/herdr-app/mods/agent-chooser`. The latter checks
initial rendering, not deferred virtual-list rows; also open it in the app.

## Unsupported or not yet matched (Herdr-app 0.1.13)

- Ghostty's `adjust-cell-height = 40%`: no configurable terminal line height.
  Herdr calculates it from font metrics with a hard-coded multiplier; changing
  terminal font size cannot reproduce extra line spacing without enlarging glyphs.
- Cursor height, cursor-text color, underline position/thickness, and custom
  cursor shaders have no equivalent documented setting.
- Terminal padding remains the shipped layout's; matching Ghostty's 8px padding
  requires a personal layout. Do not edit shipped layouts or mods in place.
- Ghostty's Cmd-k/Cmd-o send Herdr TUI prefix sequences; do not copy those into
  the GUI app blindly.

References: the installed `~/.config/herdr-app/AGENTS.md`, and upstream
[`src/settings.rs`](https://github.com/herdrdev/herdr-app/blob/master/src/settings.rs)
and [`src/terminal.rs`](https://github.com/herdrdev/herdr-app/blob/master/src/terminal.rs).
