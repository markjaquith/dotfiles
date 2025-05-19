# Define DIR as the directory of this file.
DIR=$(dirname "$0")

# Squashes png files.
alias pngfix="pkgx pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB $1 $2"

# Opens a file in Sublime Text.
alias o="subl"
alias s="subl"

function subl() {
	if [[ ! -p /dev/stdin ]]; then
		command subl > /dev/null 2>&1
	fi
	command subl "$@"
}

function p() {
	pet exec -q "$*"
}

function pt() {
	pet exec -t "$*"
}

open_tmux_urls() {
  local urls count selected

  # Capture URLs from the tmux pane
  urls=$(tmux capture-pane -J -p | grep -oE "(https?)://[^ >]+" | sed 's/"$//' | sort -u)
  count=$(echo "$urls" | wc -l)

  if [[ -z "$urls" ]]; then
    echo "No URLs detected"
    sleep 0.5
    return
  fi

  if [[ "$count" -eq 1 ]]; then
    open "$urls"
  else
    selected=$(echo "$urls" | gum choose --no-limit)
    [[ -n "$selected" ]] && echo "$selected" | tr '\n' ' ' | xargs open
  fi
}

decrypt_and_install_fonts() {
    local FONT_DIR="$HOME/Library/Fonts"
    local FONT_SOURCE_DIR="$HOME/dotfiles/.fonts"

    # Ensure the source directory exists
    if [[ ! -d "$FONT_SOURCE_DIR" ]]; then
        echo "Error: Font directory '$FONT_SOURCE_DIR' does not exist."
        return 1
    fi

    # Move into the font source directory
    cd "$FONT_SOURCE_DIR" || return 1

    local ENCRYPTED_FONTS=()

    # Find all .otf.gpg files and compute expected font names
    for file in *.otf.gpg(.N); do
        ENCRYPTED_FONTS+=("${file%.gpg}")  # Remove .gpg extension
    done

		# Find all .ttf files
		for file in *.ttf(.N); do
			BARE_FONTS+=("${file}")
		done

		# Combine arrays
		local ALL_FONTS=("${ENCRYPTED_FONTS[@]}" "${BARE_FONTS[@]}")

    # Exit if no font files are found
    if [[ ${#ALL_FONTS[@]} -eq 0 ]]; then
        echo "No font files found in $FONT_SOURCE_DIR."
        return 1
    fi

    # Check if all expected fonts already exist
    local all_fonts_exist=true
    for font in "${ALL_FONTS[@]}"; do
        if [[ ! -f "$FONT_DIR/$font" ]]; then
            all_fonts_exist=false
            break
        fi
    done

    # Exit silently if all fonts exist
    if [[ $all_fonts_exist == true ]]; then
        return 0
    fi

    # Prompt for passphrase
    echo "Enter passphrase for decryption:"
    read -s passphrase

    # Decrypt and move fonts
    for file in *.otf.gpg(.N); do
        local output_file="${file%.gpg}"
        gpg --batch --yes --passphrase "$passphrase" --output "$output_file" --decrypt "$file"
        mv "$output_file" "$FONT_DIR/"
    done

		# Copy non-encrypted fonts
		for file in *.ttf(.N); do
			cp "$file" "$FONT_DIR/"
		done
}

# Edit the hosts file.
alias hosts="o /etc/hosts"

# Open current dir in finder.
alias finder="open -a finder ."

# Nvim
alias vim="nvim"
alias vi="nvim"

# Directory listing.
alias la="eza --color --long --icons --no-time --no-user --no-permissions --all --no-filesize --classify"

function zz() {
	z "$@" && la
}

# Get the IP address for a domain.
function ipfor(){ dig +short $1 | grep -E '^[0-9.]+$' | head -1; }

# Directory size.
function sizeof(){ du -hs $1 | awk '{print $1}'; }

# gti => git typos.
alias gti="git"

# Find.
alias f='find . -name '

function findends() {
	find . -name "*.$1"
}

function rmends() {
	find . -name "*.$1" -print0 | xargs -0 rm
}

# Open current dir in finder.
alias finder="open -a finder ."

# Set terminal title.
function title {
	printf "\033]0;%s\007" "$1"
}

# Git aliases.
alias gl="git pull"
alias gp="git push"
alias gs="git status -s"
alias gss="git status"
alias gb="git branch"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gd="git diff"
alias gds="git diff --staged"
alias ga="git add"
alias gc="git commit"
alias gcm="git commit -m"
alias gbb="git checkout \$(git branch | fzf)"

# Lazygit.
alias lg="lazygit"

# ------------------------------------------------------------------------------
# Aliases and functions for tmux from Jesse Leite
# ------------------------------------------------------------------------------

# Open or create new session via fuzzy finder, or pass z style arg
t() {
  if [ -n "$1" ]; then
    sesh connect $(sesh list -c | rg $1 || echo $1)
    return
  fi

  sesh connect $(mysesh)
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

# Ensure attached to session when opening new terminal windows
# NOTE: This function should be run at the end of our zshrc script to ensure
# the rest of our config is loaded if we ctrl-c out of the session picker
tmux_ensure_session() {
  if [ -z "$TMUX" ]; then
    t
  fi
}

# Kill session with z style argument, or kill current session if no argument
tks() {
  if [ -n "$1" ]; then
    tmux kill-session -t $(sesh list -c | rg $1 || echo $1)
    return
  fi

  tmux kill-session -t .
}

# Scans a directory for all files and prints their contents in markdown code blocks
# This is useful for sending context to an LLM.
#
# Usage: llm_files [directory] | pbcopy
llm_files_old() {
	# Define the directory to scan (defaults to current directory)
	DIRECTORY=${1:-.}

	# Use recursive globbing to find all files in the directory and subdirectories
	for FILE in ${(f)"$(find "$DIRECTORY" -type f)"}; do
		# Get the relative path of the file
		RELATIVE_PATH=$(perl -MCwd -e 'use File::Spec; print File::Spec->abs2rel($ARGV[0], $ARGV[1])' "$FILE" "$DIRECTORY")

		# Print the file path and its contents in the desired format
		echo "$RELATIVE_PATH:"
		echo '```'
		cat "$FILE"
		echo '```'
		echo
	done
}

# Uses repomix to scan the current directory for files and puts them in a format for LLMs
function llm_files() {
	bunx repomix && cat repomix-output.xml | pbcopy
}


