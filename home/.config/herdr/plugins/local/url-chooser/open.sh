#!/usr/bin/env bash
set -euo pipefail

ensure_tool() {
	local tool="$1" mise_bin tool_path
	command -v "$tool" >/dev/null 2>&1 && return
	mise_bin=$(command -v mise 2>/dev/null) || return
	tool_path=$("$mise_bin" -C "$HOME" which "$tool" 2>/dev/null) || return
	export PATH="$(dirname "$tool_path"):$PATH"
}

ensure_tool jq

herdr="${HERDR_BIN_PATH:-herdr}"
target=""
cwd="${HOME}"

if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
	target=$(jq -r '.focused_pane_id // .pane_id // .pane.pane_id // empty' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
	cwd=$(jq -r '.focused_pane_cwd // .workspace_cwd // env.HOME' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
fi

args=(plugin pane open --plugin "$HERDR_PLUGIN_ID" --entrypoint picker --placement popup --cwd "$cwd" --focus)

if [[ -n "$target" ]]; then
	args+=(--env "HERDR_URL_CHOOSER_TARGET_PANE=$target")
fi

exec "$herdr" "${args[@]}"
