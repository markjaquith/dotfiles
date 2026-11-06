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

Imported theme data is saved under `Workspace.customThemes` alongside the selected
theme IDs. Applying preferences restores that data before selecting the theme;
no manual import or Remote Control permission is needed to restore it.

The installer applies saved preferences; it does not continuously sync changes
made inside the app. Only the appearance keys listed in `bin/rex-settings`
are eligible. Missing keys are left untouched, not deleted or reset.

`init.lua` binds Ctrl-H/J/K/L to focus the left/down/up/right pane. Run
`rex config check` and `rex config reload` after editing it.

`themes/Catppuccin Macchiato` matches Ghostty's palette, including the cursor-text
override in the Ghostty config. Import it through Rex's Import Theme File action
or, with Remote Control enabled, `rex -C CLIENT do client.theme.import
path="$HOME/.config/rex/themes/Catppuccin Macchiato"`.
