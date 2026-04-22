#!/bin/zsh

# Get current input device
currentMic=$(system_profiler SPAudioDataType 2>/dev/null | awk '
/^[[:space:]]{8}[^:][^:]*:$/ {
	device = $0
	sub(/^[[:space:]]+/, "", device)
	sub(/:$/, "", device)
	next
}

/^[[:space:]]+Default Input Device: Yes$/ {
	print device
	exit
}
')

# Fallback if empty
if [[ -z "$currentMic" ]]; then
	currentMic="Mic: Unknown"
else
	currentMic="󰍬 $currentMic"
fi

echo "$currentMic"
