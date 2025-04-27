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
    local FONT_SOURCE_DIR="$HOME/dotfiles/fonts"

    # Ensure the source directory exists
    if [[ ! -d "$FONT_SOURCE_DIR" ]]; then
        echo "Error: Font directory '$FONT_SOURCE_DIR' does not exist."
        return 1
    fi

    # Move into the font source directory
    cd "$FONT_SOURCE_DIR" || return 1

    local EXPECTED_FONTS=()

    # Find all .otf.gpg files and compute expected font names
    for file in *.otf.gpg(.N); do
        EXPECTED_FONTS+=("${file%.gpg}")  # Remove .gpg extension
    done

    # Exit if no encrypted font files are found
    if [[ ${#EXPECTED_FONTS[@]} -eq 0 ]]; then
        echo "No encrypted font files found in $FONT_SOURCE_DIR."
        return 1
    fi

    # Check if all expected fonts already exist
    local all_fonts_exist=true
    for font in "${EXPECTED_FONTS[@]}"; do
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
}

# Edit the hosts file.
alias hosts="o /etc/hosts"

# Open current dir in finder.
alias finder="open -a finder ."

# Nvim
alias vim="nvim"
alias vi="nvim"

# Directory listing.
alias ls="eza"
alias la="eza --color --long --icons --no-time --no-user --no-permissions --all --no-filesize --git --classify"

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
	# Define the icons using ANSI-C quoting for special characters
	local zoxideIcon=$'' # Folder icon
	local tmuxIcon=$''   # Tmux icon

	# Get the combined, deduplicated list from sesh (without its icons)
	sesh list --hide-duplicates "$@" | while IFS= read -r line; do
		# Skip empty lines just in case
		if [[ -z "$line" ]]; then
				continue
		fi

		# Get the decimal value of the first byte of the first character.
		# ${line[1]} gets the first character in Zsh (default indexing).
		# printf '%d' "'<char>" outputs the decimal value of <char>.
		typeset -i first_byte_val # Ensure integer context for comparison
		first_byte_val=$(printf '%d' "'${line[1]}")

		# Check if the first byte value is outside the 7-bit ASCII range (0-127).
		# Values >= 128 indicate non-ASCII in UTF-8/Latin1 etc.
		# Negative values might indicate errors, but checking > 127 is the key.
		if (( first_byte_val < 0 || first_byte_val > 127 )); then
				# First byte is non-ASCII -> assume custom config with icon, pass through
				echo "$line"
		elif [[ "$line" == *"/"* ]]; then
				# First byte IS ASCII (0-127), BUT line contains '/' -> assume Zoxide path
				echo "${zoxideIcon} ${line}"
		else
				# First byte IS ASCII (0-127) and line does NOT contain '/' -> assume Tmux session
				echo "${tmuxIcon} ${line}"
		fi
	done | gum filter --no-sort --limit 1 --placeholder 'Pick a session...' --height 50 --prompt='  '
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
llm_files() {
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

