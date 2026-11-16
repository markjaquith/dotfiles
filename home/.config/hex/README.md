# Hex preferences

`preferences.json` shares portable Hex preferences using the same capture/apply
workflow as Rex. `dotfiles-install` applies them on macOS; quit Hex first.

- After changing settings in Hex, run `hex-settings capture`, review the diff in
  `~/dotfiles`, and commit it.
- Run `hex-settings apply` on another machine, then restart Hex.
- Run `hex-settings check` to validate the saved file without applying it.

The installer merges preferences into
`~/Library/Application Support/hex/settings.json`, preserving local settings.
It does not continuously sync changes made in the app.

Shared settings include shortcuts, transcription model/language, processing
prompts and rules, vocabulary, sound, appearance, and feature flags.
`portable.jq` is the allowlist; newly introduced settings require review.

Microphone/device selection, output folders, routing configuration (including API
keys and server addresses), calendar connections, recents, and migration state
stay local. History, recordings, downloaded models, personal commands, trust
decisions, local API state, and credentials are not copied. Install/download the
selected models and authenticate processing providers separately on each machine.

## Custom transformations

`hex.config.ts` is stowed directly into `~/.config/hex`. Hex reloads it on save,
so edits are shared without a capture step. It includes the spoken lowercase cue,
whitespace trimming, and optional local punctuation using Ollama's `qwen3:1.7b`
model at `127.0.0.1:11434`. Install Ollama and that model separately if using it.

Hex may ask you to trust transformations on each machine; trust is not shared.
`hex.d.ts` and `AGENTS.md` are Hex-generated reference files. Hex may regenerate
them after an update; review those changes before committing.

Typecheck transformations with
`bunx tsc --noEmit -p home/.config/hex/tsconfig.json` from the repo.
