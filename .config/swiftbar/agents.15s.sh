#!/bin/zsh

herdr=${commands[herdr]}
jq=${commands[jq]}
menu_bar_icon="| sfimage=brain.head.profile sfsize=13"

if [[ -z "$herdr" ]]; then
	for candidate in "$HOME/.local/share/mise/shims/herdr" "$HOME/.local/bin/herdr" /opt/homebrew/bin/herdr /usr/local/bin/herdr; do
		if [[ -x "$candidate" ]]; then
			herdr=$candidate
			break
		fi
	done
fi

if [[ -z "$jq" ]]; then
	for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq; do
		if [[ -x "$candidate" ]]; then
			jq=$candidate
			break
		fi
	done
fi

if [[ -z "$herdr" || -z "$jq" ]]; then
	echo "$menu_bar_icon"
	exit 0
fi

agentCounts=$("$herdr" agent list 2>/dev/null | "$jq" -r '
	[.result.agents[]?] |
	([.[] | select(.agent_status == "working")] | length) as $working |
	([.[] | select(.agent_status == "blocked")] | length) as $blocked |
	([.[] | select(.agent_status == "done")] | length) as $done |
	[$working, $done, $blocked] | @tsv
')

if [[ -z "$agentCounts" ]]; then
	agentCounts=$'0\t0\t0'
fi

IFS=$'\t' read -r workingCount doneCount blockedCount <<< "$agentCounts"
attentionCount=$((blockedCount + doneCount))
statusParts=()

if ((workingCount > 0)); then
	statusParts+=("▶ $workingCount")
fi
if ((doneCount > 0)); then
	statusParts+=("✓ $doneCount")
fi
if ((blockedCount > 0)); then
	statusParts+=("⚠ $blockedCount")
fi

if ((attentionCount > 0 && $(/bin/date +%s) % 120 < 15)); then
	if ((blockedCount > 0)); then
		"$herdr" notification show "Agents blocked" --body "$blockedCount agent(s) need attention" --sound request >/dev/null 2>&1
	fi
	if ((doneCount > 0)); then
		"$herdr" notification show "Agents done" --body "$doneCount agent(s) finished" --sound done >/dev/null 2>&1
	fi
fi

agentStatus="${(j:  :)statusParts}"
echo "${agentStatus:+$agentStatus }$menu_bar_icon"
