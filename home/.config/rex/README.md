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

The installer applies saved preferences; it does not continuously sync changes
made inside the app. Only the six appearance keys listed in `bin/rex-settings`
are eligible. Missing keys are left untouched, not deleted or reset.
