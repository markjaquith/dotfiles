#!/bin/zsh

switchAudioSource=${commands[SwitchAudioSource]}

if [[ -z "$switchAudioSource" ]]; then
	for candidate in /opt/homebrew/bin/SwitchAudioSource /usr/local/bin/SwitchAudioSource; do
		if [[ -x "$candidate" ]]; then
			switchAudioSource=$candidate
			break
		fi
	done
fi

if [[ -z "$switchAudioSource" ]]; then
	echo "󰍬 Unknown"
	echo "---"
	echo "SwitchAudioSource not installed"
	echo "run: brew install switchaudio-osx"
	exit 0
fi

currentMic=$($switchAudioSource -c -t input 2>/dev/null)

displayMic=$currentMic

if [[ "$displayMic" == "MacBook Pro Microphone" ]]; then
	displayMic="MBP"
fi

if [[ -z "$currentMic" ]]; then
	echo "󰍬 Unknown"
else
	echo "󰍬 $displayMic"
fi

echo "---"

$switchAudioSource -a -t input -f json 2>/dev/null | while IFS= read -r deviceJson; do
	[[ -z "$deviceJson" ]] && continue

	deviceName=$(printf '%s\n' "$deviceJson" | sed -E 's/.*"name": "([^"]+)".*/\1/')
	deviceId=$(printf '%s\n' "$deviceJson" | sed -E 's/.*"id": "([^"]+)".*/\1/')
	prefix=""

	if [[ "$deviceName" == "$currentMic" ]]; then
		prefix="✓ "
	fi

	printf "%s%s | bash='%s' param1='-t' param2='input' param3='-i' param4='%s' terminal=false refresh=true\n" \
		"$prefix" "$deviceName" "$switchAudioSource" "$deviceId"
done

echo "---"
echo "Open Sound Settings | bash='open' param1='x-apple.systempreferences:com.apple.preference.sound?input' terminal=false"
