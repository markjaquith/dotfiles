#!/usr/bin/env bash
set -euo pipefail

AGENT_CHOOSER_OPEN_FUNCTIONS_ONLY=1
source .config/herdr/plugins/local/agent-chooser/open.sh
unset AGENT_CHOOSER_OPEN_FUNCTIONS_ONLY

height_fixture() {
	local count="$1" screen_height="$2"
	jq -n \
		--argjson count "$count" \
		--argjson screen_height "$screen_height" '
		{
			result: {
				snapshot: {
					agents: [range(0; $count)],
					focused_tab_id: "w1:t1",
					layouts: [{tab_id: "w1:t1", area: {height: $screen_height}}]
				}
			}
		}
	'
}

[[ "$(popup_height <(height_fixture 2 40))" == 11 ]]
[[ "$(popup_height <(height_fixture 12 40))" == 21 ]]
[[ "$(popup_height <(height_fixture 50 30))" == 30 ]]

AGENT_CHOOSER_FUNCTIONS_ONLY=1
source .config/herdr/plugins/local/agent-chooser/picker.sh
unset AGENT_CHOOSER_FUNCTIONS_ONLY

cache_dir=$(mktemp -d "${TMPDIR:-/tmp}/agent-chooser-test.XXXXXX")
trap 'rm -rf "$cache_dir"' EXIT

snapshot() {
	local done_seq="${1:-10}" blocked_seq="${2:-20}"
	jq -n \
		--argjson done_seq "$done_seq" \
		--argjson blocked_seq "$blocked_seq" '
		{
			result: {
				snapshot: {
					agents: [
						{agent_status: "idle", workspace_id: "w1", tab_id: "w1:t1", pane_id: "w1:p1"},
						{agent_status: "working", state_change_seq: 5, workspace_id: "w1", tab_id: "w1:t1", pane_id: "w1:p2"},
						{agent_status: "done", state_change_seq: $done_seq, workspace_id: "w1", tab_id: "w1:t1", pane_id: "w1:p3"},
						{agent_status: "blocked", state_change_seq: $blocked_seq, workspace_id: "w2", tab_id: "w2:t2", pane_id: "w2:p4"}
					],
					workspaces: [
						{workspace_id: "w1", label: "Agency"},
						{workspace_id: "w2", label: "Gusto"}
					],
					tabs: [
						{tab_id: "w1:t1", label: "Polish README"},
						{tab_id: "w2:t2", label: "CAN-1922"}
					]
				}
			}
		}
	'
}

snapshot >"$cache_dir/snapshot"
build_views "$cache_dir/snapshot"

[[ "$(wc -l <"$cache_dir/attention" | tr -d ' ')" == 2 ]]
[[ "$(wc -l <"$cache_dir/working" | tr -d ' ')" == 1 ]]
[[ "$(wc -l <"$cache_dir/all" | tr -d ' ')" == 4 ]]
[[ "$(awk -F '\t' 'NR == 1 { print $4 }' "$cache_dir/attention")" == "w2:p4" ]]
[[ "$(initial_view)" == attention ]]

: >"$cache_dir/attention"
[[ "$(initial_view)" == working ]]
: >"$cache_dir/working"
[[ "$(initial_view)" == all ]]

[[ "$(next_view attention tab)" == working ]]
[[ "$(next_view working tab)" == all ]]
[[ "$(next_view all tab)" == attention ]]
[[ "$(next_view attention btab)" == all ]]
[[ "$(tab_header attention)" == $'\033[1;38;2;30;32;48;48;2;138;173;244m Attention \033[0m \033[38;2;128;135;162m Working \033[0m \033[38;2;128;135;162m All \033[0m\n ' ]]

printf 'attention' >"$cache_dir/active"
action=$(reload_action attention)
[[ "$action" == transform-header* ]]
[[ "$action" == *" header attention)+reload("* ]]

refresh_count_file="$cache_dir/refresh-count"
printf '0' >"$refresh_count_file"
mock_herdr() {
	local count
	count=$(<"$refresh_count_file")
	printf '%s' "$((count + 1))" >"$refresh_count_file"
	snapshot 30 40
}
herdr=mock_herdr
FZF_IDLE_TIME_MS=500
[[ -z "$(periodic_refresh)" ]]
[[ "$(<"$refresh_count_file")" == 1 ]]
[[ "$(awk -F '\t' 'NR == 1 { print $4 }' "$cache_dir/attention")" == "w2:p4" ]]

FZF_IDLE_TIME_MS=1000
action=$(periodic_refresh)
[[ "$action" == transform-header* ]]
[[ "$(<"$refresh_count_file")" == 2 ]]

printf 'agent-chooser tests passed\n'
