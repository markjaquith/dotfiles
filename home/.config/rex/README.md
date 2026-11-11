# Rex preferences

`preferences.json` contains only allowlisted appearance preferences. Window
geometry, sessions, servers, device identity, and update state are never captured
or changed by this setup.

- Quit Rex before running `dotfiles-install` or `rex-settings apply`.
- After changing Rex settings, run `rex-settings capture`, review the diff in
  `~/dotfiles`, and commit it. Capture writes through the stowed config symlink.
- Run `rex-settings check` to validate the saved preferences without applying them.
- Restart Rex after applying. Install the selected font on each machine; theme
  availability may depend on the installed Rex version.

`Workspace.appearance` is `dark`, so Rex always uses the dark theme regardless
of the macOS appearance. Rex rejects dark themes as `lightThemeID`.

Imported theme data is saved under `Workspace.customThemes` alongside the selected
theme IDs. Applying preferences restores that data before selecting the theme;
no manual import or Remote Control permission is needed to restore it.

The installer applies saved preferences; it does not continuously sync changes
made inside the app. Only the appearance keys listed in `bin/rex-settings`
are eligible. Missing keys are left untouched, not deleted or reset.

`dotfiles-install` links the `rex` CLI bundled inside Rex.app to
`~/.local/bin/rex` and caches its zsh completion in
`~/.local/share/rex/completion.zsh`. Both are skipped silently when Rex is not
installed; rerun `dotfiles-install` after moving or renaming the app.

`init.lua` binds Ctrl-H/J/K/L to focus the left/down/up/right pane and
Opt-H/L to show the previous/next tab. Run
`rex config check` and `rex config reload` after editing it.

`mux.lua` ports the Herdr plugins:

| Key          | Action                                                               | Herdr equivalent             |
| ------------ | -------------------------------------------------------------------- | ---------------------------- |
| Ctrl-H/J/K/L | `nav`: send the key to Vim (or a nested Herdr), else move pane focus | vim-herdr-navigation         |
| Shift-Cmd-T  | `tab_new_here`: new tab in the focused pane's directory              | new-tab-cwd `prefix+c`       |
| Ctrl-Cmd-T   | `tab_new_first`: new tab in the first pane's directory               | new-tab-cwd `prefix+shift+c` |
| Ctrl-Cmd-U   | `url_choose`: float `bin/rex-url-chooser` over the pane              | url-chooser `prefix+shift+o` |

Neovim's side of Ctrl-H/J/K/L is `nvim/lua/rex_navigation.lua`. The agent
chooser is Agentodon's `agents_choose`. Test with `lua test/rex-mux.test.lua`
and `zsh test/rex-url-chooser.test.zsh`.

`prefix.lua` ports Herdr's Ctrl-B prefix bindings as Rex key sequences (press
Ctrl-B, release, then the key). Rex's own shortcuts are unchanged. Herdr
workspaces map to Rex sessions.

| Keys after Ctrl-B | Action                                                  |
| ----------------- | ------------------------------------------------------- |
| C / Shift-C       | new tab in focused / first pane's directory             |
| N / P, 1–9        | next / previous tab, go to tab N                        |
| Shift-T / Shift-X | rename / close tab                                      |
| V / -             | split right / down                                      |
| X / Z             | close / zoom pane                                       |
| H/J/K/L           | focus pane in that direction                            |
| Shift-H/J/K/L     | swap pane in that direction                             |
| Tab / Shift-Tab   | next / previous pane                                    |
| Shift-P           | rename pane                                             |
| R                 | resize mode (H/J/K/L or arrows, Shift for bigger steps) |
| Shift-N / W       | new session / switch session                            |
| Shift-W / Shift-D | rename / close session                                  |
| G                 | Go to Anything                                          |
| B                 | toggle Agentodon sidebar                                |
| Shift-O           | URL chooser                                             |
| S / Shift-R       | settings / reload config                                |
| Ctrl-B            | send Ctrl-B to the terminal                             |

In resize mode, `=` balances splits and Enter or Escape leaves.
Not ported: layout cycling, copy mode, edit scrollback, new worktree, detach.
Test with `lua test/rex-prefix.test.lua`.

`themes/Catppuccin Macchiato` matches Ghostty's palette, including the cursor-text
override in the Ghostty config. Import it through Rex's Import Theme File action
or, with Remote Control enabled, `rex -C CLIENT do client.theme.import
path="$HOME/.config/rex/themes/Catppuccin Macchiato"`.
