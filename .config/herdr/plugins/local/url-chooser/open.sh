#!/usr/bin/env bash
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
target=""
cwd="${HOME}"

if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
	target=$(jq -r '.focused_pane_id // .pane_id // .pane.pane_id // empty' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
	cwd=$(jq -r '.focused_pane_cwd // .workspace_cwd // env.HOME' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
fi

args=(plugin pane open --plugin "$HERDR_PLUGIN_ID" --entrypoint picker --placement overlay --cwd "$cwd" --focus)

if [[ -n "$target" ]]; then
	args+=(--env "HERDR_URL_CHOOSER_TARGET_PANE=$target")
fi

exec "$herdr" "${args[@]}"
