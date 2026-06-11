#!/bin/zsh

ocmon=${commands[ocmon]}
jq=${commands[jq]}
menu_bar_icon="| sfimage=brain.head.profile sfsize=13"

if [[ -z "$ocmon" ]]; then
	for candidate in "$HOME/.bun/bin/ocmon" /opt/homebrew/bin/ocmon /usr/local/bin/ocmon; do
		if [[ -x "$candidate" ]]; then
			ocmon=$candidate
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

if [[ -z "$ocmon" || -z "$jq" ]]; then
	echo "Idle $menu_bar_icon"
	exit 0
fi

opencodeStatus=$($ocmon list --format json 2>/dev/null | $jq -r '
	if any(.[]; .status == "working") then
		"Working"
	elif any(.[]; .status == "blocked" or (.status == "idle" and (((now * 1000) - .last_status_changed_at) < 300000))) then
		"Waiting"
	else
		"Idle"
	end
')

if [[ -z "$opencodeStatus" ]]; then
	opencodeStatus="Idle"
fi

echo "$opencodeStatus $menu_bar_icon"
