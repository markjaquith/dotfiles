#!/usr/bin/env bash
set -euo pipefail

extract_urls() {
	grep -oE 'https?://(localhost|[[:alnum:]-]+(\.[[:alnum:]-]+)+)(:[0-9]+)?(/[^[:space:]<>"'"'"'{}\]*)?' | while IFS= read -r url; do
		while true; do
			case "$url" in
				*[.,\;:!?]) url="${url%?}" ;;
				*')')
					opens="${url//[^(]}"
					closes="${url//[^)]}"
					[[ ${#closes} -gt ${#opens} ]] && url="${url%?}" || break
					;;
				*']')
					lefts="${url//[^[]}"
					rights="${url//[^]]}"
					[[ ${#rights} -gt ${#lefts} ]] && url="${url%?}" || break
					;;
				*) break ;;
			esac
		done
		printf '%s\n' "$url"
	done | sort -u
}

pause() {
	printf '\nPress any key to close'
	IFS= read -r -n 1 _ || sleep 10
}

herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_URL_CHOOSER_TARGET_PANE:-}"

if [[ -z "$pane" && -n "${HERDR_PANE_ID:-}" ]]; then
	pane="$HERDR_PANE_ID"
fi

if [[ -z "$pane" ]]; then
	printf 'No Herdr pane detected\n'
	pause
	exit 0
fi

lines="${HERDR_URL_CHOOSER_LINES:-}"
if [[ -z "$lines" ]] && command -v jq >/dev/null 2>&1; then
	lines=$("$herdr" pane layout --pane "$pane" 2>/dev/null \
		| jq -r --arg pane "$pane" '.result.layout.panes[]? | select(.pane_id == $pane) | .rect.height // empty')
fi

raw=$("$herdr" pane read "$pane" --source recent-unwrapped --lines "${lines:-100}" --format text)
urls=$(printf '%s\n' "$raw" | extract_urls)

if [[ -z "$urls" ]]; then
	printf 'No URLs detected in pane %s\n' "$pane"
	pause
	exit 0
fi

count=$(printf '%s\n' "$urls" | wc -l | tr -d ' ')
if [[ "$count" -eq 1 ]]; then
	open "$urls"
	exit 0
fi

if command -v fzf >/dev/null 2>&1; then
	selected=$(printf '%s\n' "$urls" | fzf --ansi --expect=y --prompt='URL> ')
	action="${selected%%$'\n'*}"
	selected="${selected#*$'\n'}"

	case "$action" in
		y)
			[[ -n "$selected" ]] && printf '%s' "$selected" | pbcopy
			;;
		*)
			[[ -n "$selected" ]] && open "$selected"
			;;
	esac
elif command -v gum >/dev/null 2>&1; then
	selected=$(printf '%s\n' "$urls" | gum choose)
	[[ -n "$selected" ]] && open "$selected"
else
	printf 'fzf or gum is required to choose from multiple URLs:\n%s\n' "$urls"
	pause
fi
