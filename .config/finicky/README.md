# Finicky

`finicky.ts` sends Google Meet URLs to the locally built Google Meet Router.
Build and register it with:

```sh
bin/build-google-meet-router
```

## Google Meet Router

The router has two responsibilities:

1. `google-meet-router.applescript` navigates the active Google Meet PWA tab to
   the requested URL.
2. `google-meet-join.swift` searches the PWA accessibility tree for `Join now`,
   `Ask to join`, or `Join anyway`, then clicks the first match.

The join helper checks every 50 ms for the first five seconds. It then doubles
the interval up to a 500 ms maximum and stops after 30 seconds. After clicking
the initial join button, it waits up to 10 seconds for the optional Gemini notes
dialog and clicks that dialog's `Join now` button.

The router gives the PWA one second to discard controls from the previous page,
then starts a fresh helper instance. This prevents a stale join control or a
still-running helper from consuming the new attempt.

### Automation Boundaries

- Chrome's AppleScript dictionary can navigate a Chrome PWA tab, but executing
  JavaScript requires Chrome's separate "Allow JavaScript from Apple Events"
  setting. The router intentionally does not depend on that setting.
- Clicking occurs through the Google Meet PWA's native macOS accessibility tree.
  The helper uses the button's accessibility `Press` action, which works while
  the PWA is in the background. It unminimizes and raises the window before
  falling back to a physical click. Running the helper from a terminal is not a
  valid permission test because the terminal may already have Accessibility
  access.
- macOS Accessibility approval is tied to the helper's designated requirement,
  not only its path or bundle identifier. The helper is ad-hoc signed with an
  explicit requirement based on its fixed bundle identifier, so recompiling it
  does not change the identity stored by TCC.
- Do not deep-sign the outer router afterward; that would replace the nested
  helper's signature and its explicit designated requirement.
- Permission prompting must remain conditional on `AXIsProcessTrusted()`.
  Calling `AXIsProcessTrustedWithOptions` with prompting enabled on every launch
  can repeatedly open Accessibility settings.

### Troubleshooting

Builds made before the stable designated requirement was added used the helper's
CDHash as its identity. Clear that stale approval once, then invoke the router:

```sh
tccutil reset Accessibility local.finicky.google-meet-router.join-helper
```

Approve **Google Meet Join Helper** when prompted, then restart any helper that
was launched before approval.

Verify the installed bundle after rebuilding:

```sh
codesign --verify --deep --strict \
  "$HOME/Applications/Google Meet Router.app"
```
