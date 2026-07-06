#!/usr/bin/env bash
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
mode="${1:-current}"
workspace=""
pane=""
cwd=""

json_value() {
	local query="$1"

	if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
		jq -r "$query // empty" <<<"$HERDR_PLUGIN_CONTEXT_JSON"
	fi
}

pane_cwd() {
	local target="$1"

	if [[ -n "$target" ]] && command -v jq >/dev/null 2>&1; then
		"$herdr" pane get "$target" 2>/dev/null \
			| jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty'
	fi
}

workspace=$(json_value '.workspace_id')

case "$mode" in
	current)
		pane=$(json_value '.focused_pane_id')
		cwd=$(pane_cwd "$pane")
		if [[ -z "$cwd" ]]; then
			cwd=$(json_value '.focused_pane_cwd')
		fi
		;;
	first)
		if [[ -n "$workspace" ]] && command -v jq >/dev/null 2>&1; then
			cwd=$(
				"$herdr" pane list --workspace "$workspace" 2>/dev/null \
					| jq -r '.result.panes[0].foreground_cwd // .result.panes[0].cwd // empty'
			)
		fi
		;;
	*)
		printf 'Unknown mode: %s\n' "$mode" >&2
		exit 2
		;;
esac

if [[ -z "$cwd" ]]; then
	cwd=$(json_value '.workspace_cwd')
fi

if [[ -z "$cwd" ]]; then
	cwd="$HOME"
fi

args=(tab create --cwd "$cwd" --focus)
if [[ -n "$workspace" ]]; then
	args+=(--workspace "$workspace")
fi

exec "$herdr" "${args[@]}"
