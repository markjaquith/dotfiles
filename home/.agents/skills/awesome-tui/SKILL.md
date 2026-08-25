---
name: awesome-tui
description: Use when designing, implementing, debugging, testing, or reviewing any TUI, terminal UI, interactive CLI, or terminal tool. Enforces predictable keyboard navigation, readline-style text editing, discoverable controls, and safe terminal behavior.
---

# Awesome TUI

Build terminal interfaces that feel native to experienced terminal users. Apply
these rules to new behavior and use them as review criteria for existing
behavior.

## Text Input

Every text input must support the common Emacs/readline editing bindings in
addition to normal arrow, Home, End, Backspace, and Delete keys:

| Binding | Behavior                                            |
| ------- | --------------------------------------------------- |
| `C-a`   | Move to the beginning of the line                   |
| `C-e`   | Move to the end of the line                         |
| `C-b`   | Move backward one character                         |
| `C-f`   | Move forward one character                          |
| `M-b`   | Move backward one word                              |
| `M-f`   | Move forward one word                               |
| `C-u`   | Delete from the cursor to the beginning of the line |
| `C-k`   | Delete from the cursor to the end of the line       |
| `C-w`   | Delete the previous word                            |
| `C-d`   | Delete the character under the cursor               |
| `C-h`   | Delete the character before the cursor              |
| `C-y`   | Yank the most recently deleted text when practical  |

Preserve the terminal's conventional character and word boundaries where the
TUI framework supports them. Do not silently omit bindings merely because the
framework's default text input does not implement them; add the missing
behavior or choose a suitable input component.

## List Navigation

- `C-n` moves to the next item in a list.
- `C-p` moves to the previous item in a list.
- `C-n` and `C-p` navigate the list even while its filtering input is focused.
- If a view has no text filtering input, `j` and `k` move to the next and
  previous list items when no other text input is focused.
- Never interpret `j`, `k`, or `?` as commands while a text input is focused.
- Keep arrow-key navigation available alongside these bindings.
- Handle empty lists and list boundaries without panics, invalid selections, or
  unintended actions.

## Global Controls

- `C-c` quits the application. Restore terminal modes, cursor visibility, and
  alternate-screen state before exiting.
- `Esc` cancels or closes exactly one active layer, such as a dialog, menu, or
  transient mode. It must not quit the application.
- Do not bind `q` to quit.
- `?` opens contextual keybinding help when no text input is focused.
- Keep help accurate as bindings change. Prefer showing important available
  bindings in the interface instead of requiring users to guess them.

## Key Precedence

Resolve overlapping bindings in this order:

1. `C-c` quits cleanly from every context.
2. An active modal, prompt, or transient mode handles its documented keys.
3. A focused text input handles text-editing keys and literal text.
4. `C-n` and `C-p` may update the associated list selection while a filter is
   focused.
5. The focused list or view handles navigation and activation keys.
6. Contextual controls such as `Esc` and help run last unless an earlier layer
   explicitly consumes them.

Make focus visible. A user should be able to predict whether a key will type,
navigate, cancel, or act before pressing it.

## Implementation Guidance

- Inspect the TUI framework's input event model and existing project
  conventions before adding custom key handling.
- Centralize binding definitions or command dispatch when practical so help,
  implementation, and tests cannot drift independently.
- Match keys by decoded key identity rather than fragile raw byte comparisons
  when the framework provides that abstraction.
- Ensure cleanup runs for normal exits, `C-c`, handled errors, and panics or
  exceptions where the language permits it.
- Preserve usable behavior after terminal resize and at narrow dimensions.
- Do not rely on color alone to communicate focus, selection, or status.

## Verification

Exercise the interface in a real terminal, not only through component tests.
Verify:

- Every text input supports the required readline bindings.
- Filtering and `C-n`/`C-p` navigation work simultaneously.
- `j`, `k`, and `?` remain literal input characters while typing.
- Empty, single-item, first-item, and last-item list states are safe.
- `Esc` closes one layer without quitting and `q` does not quit.
- `C-c` exits and leaves the terminal fully restored.
- Help lists the actual bindings available in the current context.
- Key handling works in the terminals and multiplexers supported by the
  project.
