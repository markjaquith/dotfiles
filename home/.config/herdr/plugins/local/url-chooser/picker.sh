#!/usr/bin/env bash
set -euo pipefail

ensure_tool() {
	local tool="$1" mise_bin tool_path
	command -v "$tool" >/dev/null 2>&1 && return
	mise_bin=$(command -v mise 2>/dev/null) || return
	tool_path=$("$mise_bin" -C "$HOME" which "$tool" 2>/dev/null) || return
	export PATH="$(dirname "$tool_path"):$PATH"
}

extract_urls() {
	grep -oE 'https?://(localhost|[[:alnum:]-]+(\.[[:alnum:]-]+)+)(:[0-9]+)?(/[^[:space:]<>"'"'"'`{}\]*)?' | while IFS= read -r url; do
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

join_wrapped_urls() {
	local pane_width="${1:-0}"
	local min_width line line_length pending continuation

	if [[ ! "$pane_width" =~ ^[0-9]+$ ]] || ((pane_width <= 10)); then
		cat
		return
	fi

	# Herdr's pane rectangle includes surrounding chrome. Pi hard-wraps transcript
	# text inside that boundary, while terminal soft wraps have already been joined.
	min_width=$((pane_width - 10))
	pending=""
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -n "$pending" ]]; then
			continuation="$line"
			if [[ "$continuation" =~ ^[[:space:]]*┃ ]]; then
				continuation="${continuation#*┃}"
			fi
			continuation="${continuation#"${continuation%%[![:space:]]*}"}"
			if [[ -n "$continuation" ]] \
				&& ! [[ "$continuation" =~ ^https?:// ]] \
				&& grep -qE '^[^[:space:]<>"'"'"'`{}\\*]' <<<"$continuation"; then
				pending+="$continuation"
				line_length=${#line}
				if ((line_length >= min_width && line_length <= pane_width)) \
					&& ! [[ "$continuation" =~ [[:space:]] ]]; then
					continue
				fi
				printf '%s\n' "$pending"
				pending=""
				continue
			fi
			printf '%s\n' "$pending"
			pending=""
		fi

		line_length=${#line}
		if ((line_length >= min_width && line_length <= pane_width)) \
			&& grep -qE 'https?://(localhost|[[:alnum:]-]+(\.[[:alnum:]-]+)+)(:[0-9]+)?(/[^[:space:]<>"'"'"'`{}\\*]*)?$' <<<"$line"; then
			pending="$line"
		else
			printf '%s\n' "$line"
		fi
	done

	if [[ -n "$pending" ]]; then
		printf '%s\n' "$pending"
	fi
}

if [[ "${URL_CHOOSER_FUNCTIONS_ONLY:-}" == "1" ]]; then
	return 0 2>/dev/null || exit 0
fi

ensure_tool jq
ensure_tool fzf
ensure_tool gum

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
width=""
if command -v jq >/dev/null 2>&1; then
	dimensions=$("$herdr" pane layout --pane "$pane" 2>/dev/null \
		| jq -r --arg pane "$pane" '.result.layout.panes[]? | select(.pane_id == $pane) | [.rect.width, .rect.height] | @tsv')
	IFS=$'\t' read -r width detected_lines <<<"$dimensions"
	[[ -z "$lines" ]] && lines="$detected_lines"
fi

raw=$("$herdr" pane read "$pane" --source recent-unwrapped --lines "${lines:-100}" --format text)
plain_urls=$(printf '%s\n' "$raw" | extract_urls)
urls=$(printf '%s\n' "$raw" | join_wrapped_urls "$width" | extract_urls)
unverified_wrapped_candidates=false
if [[ "$urls" != "$plain_urls" ]]; then
	session_file=""
	if command -v jq >/dev/null 2>&1; then
		session_file=$("$herdr" pane get "$pane" 2>/dev/null \
			| jq -r '.result.pane.agent_session.value // empty')
	fi

	while IFS= read -r url; do
		if ! grep -Fxq -- "$url" <<<"$plain_urls" \
			&& { [[ ! -f "$session_file" ]] || ! grep -aFq -- "$url" "$session_file"; }; then
			unverified_wrapped_candidates=true
			break
		fi
	done <<<"$urls"
fi

if [[ -z "$urls" ]]; then
	printf 'No URLs detected in pane %s\n' "$pane"
	pause
	exit 0
fi

count=$(printf '%s\n' "$urls" | wc -l | tr -d ' ')
if [[ "$count" -eq 1 && "$unverified_wrapped_candidates" == false ]]; then
	open "$urls"
	exit 0
fi

if command -v fzf >/dev/null 2>&1; then
	fzf_args=(--ansi --expect=y --prompt='URL> ')
	if [[ "$unverified_wrapped_candidates" == true ]]; then
		fzf_args+=(--header='Wrapped URL candidate — verify before opening')
	fi
	selected=$(printf '%s\n' "$urls" | fzf "${fzf_args[@]}")
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
	if [[ "$unverified_wrapped_candidates" == true ]]; then
		printf 'Wrapped URL candidate — verify before opening\n'
	fi
	selected=$(printf '%s\n' "$urls" | gum choose)
	[[ -n "$selected" ]] && open "$selected"
else
	printf 'fzf or gum is required to choose from multiple URLs:\n%s\n' "$urls"
	pause
fi
