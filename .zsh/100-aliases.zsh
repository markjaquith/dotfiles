# Define DIR as the directory of this file.
DIR=$(dirname "$0")

# Squashes png files.
alias pngfix="pkgx pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB $1 $2"

# Fixes PDF files by optimizing and compressing them.
function fixpdf() {
	if [[ $# -lt 1 ]]; then
		echo "Usage: fixpdf input.pdf [output.pdf]"
		echo "If output file is not specified, will use 'output.pdf'"
		return 1
	fi
	
	local input="$1"
	local output="${2:-output.pdf}"
	
	command gs \
		-sDEVICE=pdfwrite \
		-dCompatibilityLevel=1.7 \
		-dPDFSETTINGS=/default \
		-dCompressFonts=true \
		-dSubsetFonts=true \
		-dDetectDuplicateImages=true \
		-dColorImageDownsample=false \
		-dGrayImageDownsample=false \
		-dMonoImageDownsample=false \
		-dNOPAUSE -dQUIET -dBATCH \
		-sOutputFile="$output" \
		"$input"
}

# Opens a file in Sublime Text.
alias o="subl"
alias s="subl"

function subl() {
	if [[ ! -p /dev/stdin ]]; then
		command subl > /dev/null 2>&1
	fi
	command subl "$@"
}

# This is safe to do, because bat will detect when it's being piped
alias cat="bat"

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
    selected=$(echo "$urls" | gum choose)
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
    local BARE_FONTS=()

    # Find all encrypted font files (.otf.gpg and .ttf.gpg) and compute expected font names
    for file in *.otf.gpg(.N); do
        ENCRYPTED_FONTS+=("${file%.gpg}")  # Remove .gpg extension
    done
    
    for file in *.ttf.gpg(.N); do
        ENCRYPTED_FONTS+=("${file%.gpg}")  # Remove .gpg extension
    done

    # Find all plain font files (.otf and .ttf)
    for file in *.otf(.N); do
        BARE_FONTS+=("${file}")
    done
    
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

    # Prompt for passphrase if encrypted fonts exist
    local passphrase=""
    if [[ ${#ENCRYPTED_FONTS[@]} -gt 0 ]]; then
        echo "Enter passphrase for decryption:"
        read -s passphrase
    fi

    # Decrypt and move encrypted fonts
    for file in *.otf.gpg(.N) *.ttf.gpg(.N); do
        local output_file="${file%.gpg}"
        gpg --batch --yes --passphrase "$passphrase" --output "$output_file" --decrypt "$file"
        mv "$output_file" "$FONT_DIR/"
    done

    # Copy non-encrypted fonts
    for file in *.otf(.N) *.ttf(.N); do
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

function claude() {
	CLAUDE_CODE_NO_FLICKER=1 command claude "$@"
}

# Directory listing.
alias la="eza --color --long --icons --no-time --no-user --no-permissions --all --no-filesize --classify"

function zz() {
	z "$@" && la
}

function cdarb() {
	if [[ $# -ne 1 ]]; then
		echo "Usage: cdarb <name>"
		return 1
	fi

	local arb_name="$1"
	local arb_dir

	arb_dir="$(arb dir "$arb_name")"
	if [[ ! -d "$arb_dir" ]]; then
		arb new "$arb_name" || return 1
		arb_dir="$(arb dir "$arb_name")"
	fi

	if [[ ! -d "$arb_dir" ]]; then
		echo "arb directory does not exist: $arb_dir"
		return 1
	fi

	cd "$arb_dir" || return 1
}

function tailf() {
	emulate -L zsh -o extended_glob -o localtraps

	if [[ $# -ne 1 ]]; then
		echo "Usage: tailf <dir|glob>"
		echo "Examples: tailf ~/logs | tailf './*.log'"
		return 1
	fi

	if ! command -v fswatch >/dev/null 2>&1; then
		echo "tailf requires fswatch (brew install fswatch)"
		return 1
	fi

	local target="$1"
	local watch_dir pattern

	if [[ -d "$target" ]]; then
		watch_dir="${target:A}"
		pattern='*'
	else
		watch_dir="${target:h}"
		pattern="${target:t}"

		if [[ "$watch_dir" == "$target" ]]; then
			watch_dir='.'
		fi

		watch_dir="${watch_dir:A}"
		if [[ ! -d "$watch_dir" ]]; then
			echo "No such directory: $watch_dir"
			return 1
		fi
	fi

	local -a files active_files
	local tail_pid=''

	cleanup_tailf() {
		if [[ -n "$tail_pid" ]]; then
			kill "$tail_pid" >/dev/null 2>&1
			wait "$tail_pid" 2>/dev/null
			tail_pid=''
		fi
	}

	trap 'cleanup_tailf; return 130' INT TERM

	while :; do
		files=(${~watch_dir}/${~pattern}(N-.))

		if [[ "${(j:\n:)files}" != "${(j:\n:)active_files}" ]]; then
			cleanup_tailf
			active_files=("${files[@]}")

			if (( ${#active_files[@]} )); then
				tail -n 0 -F -- "${active_files[@]}" &
				tail_pid=$!
			else
				print -r -- "Waiting for matches in $watch_dir/$pattern..." >&2
			fi
		fi

		fswatch -1 --event Created --event Removed --event Renamed --event MovedFrom --event MovedTo "$watch_dir" >/dev/null 2>&1
		local fswatch_status=$?

		if (( fswatch_status != 0 )); then
			cleanup_tailf
			return "$fswatch_status"
		fi
	done
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
alias gpf="git push --force"
alias gs="git status -s"
alias gss="git status"
alias gb="git checkout \$(git branch | fzf)"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gd="git diff"
alias gds="git diff --staged"
alias ga="git add"
alias gc="git commit"
alias gcm="git commit -m"
alias branch="git branch --show-current"

# Lazygit.
alias lg="lazygit"

# OpenCode aliases.
function oc() {
	emulate -L zsh

	if [[ $# -gt 0 ]]; then
		opencode "$@"
		return $?
	fi

	if ! [[ -o interactive && -t 0 && -t 1 ]]; then
		print -u2 "Usage: oc [opencode args]"
		return 1
	fi

	if ! command -v nvim >/dev/null 2>&1; then
		print -u2 "nvim not found in PATH"
		return 1
	fi

	local prompt_file
	local prompt
	prompt_file=$(mktemp -t oc-prompt.XXXXXX) || return 1

	nvim +startinsert "$prompt_file" || {
		local status=$?
		rm -f "$prompt_file"
		return $status
	}

	prompt=$(<"$prompt_file")
	rm -f "$prompt_file"
	[[ -n "$prompt" ]] || return 1

	opencode --prompt "$prompt"
}

function ocfast() {
	emulate -L zsh

	local prompt

	if [[ $# -eq 0 ]]; then
		if [[ -o interactive && -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
			prompt=$(gum input --placeholder "Enter prompt") || return 1
			[[ -n "$prompt" ]] || return 1
			opencode run --agent fast "$prompt"
			return $?
		fi

		echo "Usage: ocfast <prompt>"
		return 1
	fi

	opencode run --agent fast "$@"
}

autoload -Uz add-zsh-hook

_autofix_preexec() {
	if [[ "$1" == autofix(|[[:space:]]*) ]]; then
		AUTOFIX_SKIP_EXIT=1
		return
	fi

	if [[ -n "${AUTOFIX_LAST_OUTPUT_FILE:-}" && -f "$AUTOFIX_LAST_OUTPUT_FILE" ]]; then
		rm -f "$AUTOFIX_LAST_OUTPUT_FILE"
	fi

	AUTOFIX_LAST_CMD="$1"
	AUTOFIX_LAST_OUTPUT_FILE=
}

_autofix_precmd() {
	local exit_code=$?

	if [[ -n "${AUTOFIX_SKIP_EXIT:-}" ]]; then
		unset AUTOFIX_SKIP_EXIT
		return
	fi

	AUTOFIX_LAST_EXIT=$exit_code
}

add-zsh-hook -d preexec _fix_preexec 2>/dev/null
add-zsh-hook -d precmd _fix_precmd 2>/dev/null
add-zsh-hook -d preexec _autofix_preexec 2>/dev/null
add-zsh-hook -d precmd _autofix_precmd 2>/dev/null
add-zsh-hook preexec _autofix_preexec
add-zsh-hook precmd _autofix_precmd

_autofix_capture() {
	local tmp
	local exit_code
	local output
	local command_string="${(j: :)${(q)@}}"

	tmp=$(mktemp) || return 1

	print -r -- "+ $command_string"

	"$@" >"$tmp" 2>&1
	exit_code=$?
	output=$(<"$tmp")

	print -r -- "$output"

	AUTOFIX_LAST_CMD="$command_string"
	AUTOFIX_LAST_EXIT=$exit_code
	AUTOFIX_LAST_OUTPUT_FILE="$tmp"

	return $exit_code
}

autofix() {
	if (( $# > 0 )); then
		_autofix_capture "$@"
	fi

	if [[ -z "$AUTOFIX_LAST_CMD" ]]; then
		echo "No previous command captured."
		return 1
	fi

	if (( AUTOFIX_LAST_EXIT == 0 )); then
		echo "Last command succeeded; nothing to autofix."
		return 0
	fi

	local output_block=""
	if [[ -n "${AUTOFIX_LAST_OUTPUT_FILE:-}" && -r "$AUTOFIX_LAST_OUTPUT_FILE" ]]; then
		output_block="

It produced this output:

\`\`\`
$(<"$AUTOFIX_LAST_OUTPUT_FILE")
\`\`\`"
	fi

	opencode run "The last shell command was:

\`\`\`sh
$AUTOFIX_LAST_CMD
\`\`\`

It exited with status $AUTOFIX_LAST_EXIT.$output_block

Please inspect the repository, determine the problem, fix it, and rerun the command until it succeeds. Respond with a one-sentence summary of what was done."
}

# Wait for the current Git repo's working tree to become clean.
function committed() {
	emulate -L zsh

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		return 1
	fi

	local deadline=$(( EPOCHSECONDS + 180 ))

	while true; do
		if [[ -z "$(git status --porcelain=v1 --untracked-files=all 2>/dev/null)" ]]; then
			return 0
		fi

		if (( EPOCHSECONDS >= deadline )); then
			return 1
		fi

		sleep 1
	done
}

# OpenCode commit.
function commit() {
	emulate -L zsh

	local verbose=false
	local args=()

	for arg in "$@"; do
		case "$arg" in
			--help|-h)
				echo "Usage: commit [options] [args]"
				echo ""
				echo "Generates a commit message using opencode and commits."
				echo ""
				echo "Arguments:"
				echo "  staged          Only commit already-staged files"
				echo ""
				echo "Options:"
				echo "  --verbose, -v   Show opencode output while running"
				echo "  --help, -h      Show this help message"
				return 0
				;;
			--verbose|-v)
				verbose=true
				;;
			*)
				args+=("$arg")
				;;
		esac
	done

	local commit_arg="${args[*]}"
	local cmd=(opencode run "/commit${commit_arg:+ $commit_arg}")
	local can_spin=false

	if [[ -o interactive && -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
		can_spin=true
	fi

	if $verbose || ! $can_spin; then
		"${cmd[@]}"
	else
		if gum spin --title "Committing..." -- "${cmd[@]}"; then
			git log -1 --no-patch
			return 0
		fi

		return $?
	fi
}

# OpenCode rebase.
function rebase() {
	opencode run "Do \`git rebase $*\` and resolve any conflicts. Respond with a one-sentence summary of what was done"
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
