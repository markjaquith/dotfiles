#!/usr/bin/env bash
set -euo pipefail

format_agents() {
	jq -r '
		.result.snapshot as $snapshot
		| def color($hex): "\u001b[38;2;" + ($hex | join(";")) + "m";
		def reset: "\u001b[0m";
		def dim: "\u001b[2m";
		def bold: "\u001b[1m";
		def dot:
			if .agent_status == "blocked" then color([237, 135, 150]) + "●"
			elif .agent_status == "done" then color([139, 213, 202]) + "●"
			elif .agent_status == "working" then color([238, 212, 159]) + "●"
			elif .agent_status == "idle" then color([166, 218, 149]) + "○"
			else color([110, 115, 141]) + "·"
			end + reset;
		def workspace_label($id):
			($snapshot.workspaces[] | select(.workspace_id == $id) | .label) // $id;
		def tab_label($id):
			($snapshot.tabs[] | select(.tab_id == $id) | .label) // $id;
		$snapshot.agents[]
		| [
			.agent_status,
			(
				dot + "  " + bold + workspace_label(.workspace_id) + reset
				+ dim + " · " + reset
				+ tab_label(.tab_id)
			),
			(.state_change_seq // 0),
			.pane_id
		]
		| @tsv
	' "$1"
}

build_views() {
	local source="$1" agents_tmp attention_tmp working_tmp all_tmp
	agents_tmp="$cache_dir/agents.tmp.$$"
	attention_tmp="$cache_dir/attention.tmp.$$"
	working_tmp="$cache_dir/working.tmp.$$"
	all_tmp="$cache_dir/all.tmp.$$"

	format_agents "$source" >"$agents_tmp"
	awk -F '\t' '$1 == "done" || $1 == "blocked"' "$agents_tmp" \
		| sort -t $'\t' -k3,3nr >"$attention_tmp"
	awk -F '\t' '$1 == "working"' "$agents_tmp" >"$working_tmp"
	cp "$agents_tmp" "$all_tmp"

	mv "$agents_tmp" "$cache_dir/agents"
	mv "$attention_tmp" "$cache_dir/attention"
	mv "$working_tmp" "$cache_dir/working"
	mv "$all_tmp" "$cache_dir/all"
}

refresh_cache() {
	local wait_for_lock="${1:-false}" snapshot_tmp attempt=0

	while ! mkdir "$cache_dir/refresh.lock" 2>/dev/null; do
		[[ "$wait_for_lock" == true && "$attempt" -lt 20 ]] || return 1
		sleep 0.05
		attempt=$((attempt + 1))
	done

	snapshot_tmp="$cache_dir/snapshot.tmp.$$"
	if "$herdr" api snapshot >"$snapshot_tmp"; then
		build_views "$snapshot_tmp"
		mv "$snapshot_tmp" "$cache_dir/snapshot"
	else
		rm -f "$snapshot_tmp"
		rmdir "$cache_dir/refresh.lock"
		return 1
	fi

	rmdir "$cache_dir/refresh.lock"
}

tab_header() {
	local active="$1" tab label header=""

	for tab in attention working all; do
		case "$tab" in
			attention) label="Attention" ;;
			working) label="Working" ;;
			all) label="All" ;;
		esac
		if [[ "$tab" == "$active" ]]; then
			header+=$'\033[1;38;2;30;32;48;48;2;138;173;244m '"$label"$' \033[0m'
		else
			header+=$'\033[38;2;128;135;162m '"$label"$' \033[0m'
		fi
		[[ "$tab" == all ]] || header+=" "
	done

	printf '%s\n ' "$header"
}

next_view() {
	case "$1:$2" in
		attention:tab | all:btab) printf 'working' ;;
		working:tab | attention:btab) printf 'all' ;;
		all:tab | working:btab) printf 'attention' ;;
	esac
}

initial_view() {
	if [[ -s "$cache_dir/attention" ]]; then
		printf 'attention'
	elif [[ -s "$cache_dir/working" ]]; then
		printf 'working'
	else
		printf 'all'
	fi
}

reload_action() {
	local view="$1"
	printf 'transform-header(bash %q header %q)+reload(cat %q)\n' \
		"$script" "$view" "$cache_dir/$view"
}

post_reload() {
	local view
	view=$(<"$cache_dir/active")
	curl --silent --show-error --unix-socket "$FZF_SOCK" http \
		--data-binary "$(reload_action "$view")" >/dev/null
}

switch_view() {
	local key="$1" view
	view=$(next_view "$(<"$cache_dir/active")" "$key")
	printf '%s' "$view" >"$cache_dir/active"
	(bash "$script" refresh-post >/dev/null 2>&1 &)
	reload_action "$view"
}

periodic_refresh() {
	refresh_cache false || return 0
	if (( ${FZF_IDLE_TIME_MS:-0} >= 1000 )); then
		reload_action "$(<"$cache_dir/active")"
	fi
}

refresh_and_post() {
	refresh_cache true || return 0
	post_reload
}

cleanup() {
	[[ -n "${cache_dir:-}" ]] && rm -rf "$cache_dir"
	[[ -n "${fzf_socket:-}" ]] && rm -f "$fzf_socket"
	[[ -n "${HERDR_AGENT_CHOOSER_SNAPSHOT:-}" ]] && rm -f "$HERDR_AGENT_CHOOSER_SNAPSHOT"
}

main() {
	local view selected pane_id

	if ! command -v fzf >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		printf 'fzf and jq are required\n' >&2
		return 1
	fi

	cache_dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-agent-chooser.XXXXXX")
	fzf_socket="/tmp/herdr-fzf.$$.sock"
	export AGENT_CHOOSER_CACHE_DIR="$cache_dir"
	trap cleanup EXIT

	if [[ -n "${HERDR_AGENT_CHOOSER_SNAPSHOT:-}" ]]; then
		cp "$HERDR_AGENT_CHOOSER_SNAPSHOT" "$cache_dir/snapshot"
	else
		"$herdr" api snapshot >"$cache_dir/snapshot"
	fi
	build_views "$cache_dir/snapshot"
	view=$(initial_view)
	printf '%s' "$view" >"$cache_dir/active"

	selected=$(
		cat "$cache_dir/$view" | fzf \
			--ansi \
			--delimiter=$'\t' \
			--with-nth=2 \
			--id-nth=4 \
			--track \
			--layout=reverse \
			--info=hidden \
			--prompt='  ' \
			--header="$(tab_header "$view")" \
			--listen="$fzf_socket" \
			--bind="tab:transform:bash $script switch tab" \
			--bind="btab:transform:bash $script switch btab" \
			--bind="ctrl-r:bg-transform:bash $script refresh-post" \
			--bind="every(1):bg-transform:bash $script periodic"
	) || return 0

	pane_id="${selected##*$'\t'}"
	[[ -n "$pane_id" ]] && "$herdr" agent focus "$pane_id" >/dev/null
}

script="${BASH_SOURCE[0]}"
herdr="${HERDR_BIN_PATH:-herdr}"
cache_dir="${AGENT_CHOOSER_CACHE_DIR:-}"
fzf_socket=""

case "${1:-}" in
	header) tab_header "$2"; exit ;;
	switch) switch_view "$2"; exit ;;
	periodic) periodic_refresh; exit ;;
	refresh-post) refresh_and_post; exit ;;
esac

if [[ "${AGENT_CHOOSER_FUNCTIONS_ONLY:-}" == "1" ]]; then
	return 0 2>/dev/null || exit 0
fi

main
