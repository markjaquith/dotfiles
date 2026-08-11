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
the interval up to a 500 ms maximum and stops after 30 seconds. It exits
immediately after a successful click.

### Automation Boundaries

- Chrome's AppleScript dictionary can navigate a Chrome PWA tab, but executing
  JavaScript requires Chrome's separate "Allow JavaScript from Apple Events"
  setting. The router intentionally does not depend on that setting.
- Clicking occurs through the Google Meet PWA's native macOS accessibility tree.
  Running the helper from a terminal is not a valid permission test because the
  terminal may already have Accessibility access.
- macOS Accessibility approval is tied to the helper's code signature, not only
  its path or bundle identifier. With ad-hoc signing, recompiling the helper
  changes its CDHash and requires new approval even if System Settings still
  displays a stale enabled row.
- The build script therefore preserves the exact signed helper app whenever the
  Swift source hash is unchanged. Do not deep-sign the outer router afterward;
  that would replace the nested helper's signature and invalidate approval.
- Permission prompting must remain conditional on `AXIsProcessTrusted()`.
  Calling `AXIsProcessTrustedWithOptions` with prompting enabled on every launch
  can repeatedly open Accessibility settings.

### Troubleshooting

If the helper source changed and macOS shows an enabled entry but continues to
prompt, clear only its stale approval and invoke the router again:

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
