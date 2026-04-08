# Tmux helpers that need to be available early in shell startup.

# Open or create new session via fuzzy finder, or pass z style arg.
t() {
	if [ -n "$1" ]; then
		sesh connect $(sesh list -c | rg $1 || echo $1)
		return
	fi

	sesh connect $(mysesh_simple)
}

mysesh_simple() {
	sesh list -Hd | gum filter \
		--no-sort \
		--limit 1 \
		--fuzzy \
		--no-strip-ansi \
		--indicator '󰳟' \
		--no-show-help \
		--placeholder "Pick a session..." \
		--prompt='󱐋 '
}

mysesh() {
	# Colors
	local color_zoxide=$'\e[38;2;91;96;120m'
	local color_tmux=$'\e[38;2;166;218;149m'
	local color_config=$'\e[38;2;245;169;127m'
	local color_zoxide_text=$'\e[38;2;147;154;183m'
	local color_reset=$'\e[0m'

	# Icons
	local zoxideIcon=$''
	local tmuxIcon=$''
	local configIcon=$''

	# Regex pattern to match: ANSI_CODE ICON ANSI_CODE SPACE+ NAME
	local ansi_pattern_part=$'\x1b\[[0-9;?]*[@-~]'
	local line_pattern="^(${ansi_pattern_part})([^\x1b]+)(${ansi_pattern_part})[[:space:]]+(.*)$"

	# Get current time for context (optional)
	# local current_date_display=$(date "+%A, %B %d, %Y - %I:%M %p %Z")

	sesh list --icons --hide-duplicates "$@" \
		| while IFS= read -r line; do
	# Skip empty lines
	if [[ -z "$line" ]]; then continue; fi

	if [[ "$line" =~ $line_pattern ]]; then
		local icon="${match[2]}"
		local name="${match[4]}"

		local is_custom_override=0
		local custom_icon=""
		local actual_name_if_override=""

		if [[ ${#name} -ge 2 ]]; then
			typeset -i first_byte_val=0
			first_byte_val=$(printf '%d' "'${name[1]}")

			if (( first_byte_val < 0 || first_byte_val > 127 )); then
				# Check 2: Is the second character a standard ASCII space? (Keep this specific check for triggering)
				if [[ "${name[2]}" == " " ]]; then
					is_custom_override=1
					custom_icon="${name[1]}"
					# Strip first char (icon), then strip ALL leading whitespace chars using [[:space:]]
					actual_name_if_override="${${name#?}##[[:space:]]#}"
					actual_name_if_override="${${actual_name_if_override#?}##[[:space:]]#}"
					# --- DEBUG --- Uncomment below to verify actual_name_if_override is now clean
					# print -r -- "    OVERRIDE_POST_STRIP: custom_icon=|<${custom_icon}>| actual_name=|<${actual_name_if_override}>|"
				fi
			fi
		fi

		# --- Format output using printf ---
		if [[ "$icon" == "$zoxideIcon" ]]; then
			printf '%s %s%s%s\n' "${color_zoxide}${icon}${color_reset}" "${color_zoxide_text}" "${name}" "${color_reset}"
		elif [[ "$icon" == "$tmuxIcon" ]]; then
			if (( is_custom_override )); then
				printf '%s %s\n' "${color_tmux}${custom_icon}${color_reset}" "${actual_name_if_override}"
			else
				printf '%s %s\n' "${color_tmux}${icon}${color_reset}" "${name}"
			fi
		elif [[ "$icon" == "$configIcon" ]]; then
			if (( is_custom_override )); then
				printf '%s %s\n' "${color_config}${custom_icon}${color_reset}" "${actual_name_if_override}"
			else
				printf '%s%s%s\n' "${color_config}" "${name}" "${color_reset}"
			fi
		else # Initial icon was already custom/unknown
			printf '%s %s\n' "${color_tmux}${icon}${color_reset}" "${name}" # Default Tmux color
		fi
	else # Line didn't match pattern
		print -r -- "$line"
	fi
done | gum filter \
		--no-sort \
		--limit 1 \
		--fuzzy \
		--no-strip-ansi \
		--indicator '󰳟' \
		--no-show-help \
		--placeholder "Pick a session..." \
		--prompt='󱐋 '
}

# Ensure attached to a session when opening new terminal windows.
tmux_ensure_session() {
	if [ -z "$TMUX" ]; then
		t
	fi
}

# Kill session with z style argument, or kill current session if no argument.
tks() {
	if [ -n "$1" ]; then
		tmux kill-session -t $(sesh list -c | rg $1 || echo $1)
		return
	fi

	tmux kill-session -t .
}
