#!/usr/bin/env bash
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
cwd="${HOME}"
snapshot_file=""

cleanup() {
	[[ -n "$snapshot_file" ]] && rm -f "$snapshot_file"
}

popup_height() {
	jq -r '
		.result.snapshot as $snapshot
		| (($snapshot.agents | length) + 9) as $desired
		| ([
			$snapshot.layouts[]
			| select(.tab_id == $snapshot.focused_tab_id)
			| .area.height
		] | first // 10) as $screen_height
		| [$desired, 10] | max
		| [., $screen_height] | min
	' "$1"
}

if [[ "${AGENT_CHOOSER_OPEN_FUNCTIONS_ONLY:-}" == "1" ]]; then
	return 0 2>/dev/null || exit 0
fi

if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
	cwd=$(jq -r '.focused_pane_cwd // .workspace_cwd // env.HOME' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
fi

snapshot_file=$(mktemp "${TMPDIR:-/tmp}/herdr-agent-chooser.XXXXXX")
trap cleanup EXIT
"$herdr" api snapshot >"$snapshot_file"
height=$(popup_height "$snapshot_file")

"$herdr" plugin pane open \
	--plugin "$HERDR_PLUGIN_ID" \
	--entrypoint picker \
	--placement popup \
	--width 60 \
	--height "$height" \
	--cwd "$cwd" \
	--env "HERDR_AGENT_CHOOSER_SNAPSHOT=$snapshot_file" \
	--focus

snapshot_file=""
