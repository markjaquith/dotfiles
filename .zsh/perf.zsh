# Opt-in shell performance logging.
#
# Enable for a shell (and its children) with:
#   ZSH_PERF=1 zsh
#
# By default, events are appended to $TMPDIR/zsh-perf-$UID.tsv. Override that
# with ZSH_PERF_LOG. Set ZSH_PERF_MIN_MS to omit faster command/chpwd events.
# Only command names are recorded unless ZSH_PERF_COMMAND_TEXT is non-empty.
# Fields are: epoch, pid, event, duration_ms, detail.

[[ -n "${ZSH_PERF:-}" ]] || return 0
[[ -z "${_ZSH_PERF_ACTIVE:-}" ]] || return 0

zmodload zsh/datetime || return 1
zmodload zsh/system || return 1

typeset -g _ZSH_PERF_ACTIVE=1
typeset -g _ZSH_PERF_SHELL_START="$EPOCHREALTIME"
typeset -g _ZSH_PERF_FD
typeset -g _ZSH_PERF_STARTUP_LOGGED=0
typeset -g _ZSH_PERF_COMMAND_START=''
typeset -g _ZSH_PERF_COMMAND_PWD=''
typeset -g _ZSH_PERF_COMMAND=''
typeset -g ZSH_PERF_LOG="${ZSH_PERF_LOG:-${TMPDIR:-/tmp}/zsh-perf-${UID}.tsv}"
typeset -g ZSH_PERF_MIN_MS="${ZSH_PERF_MIN_MS:-0}"
typeset -gA _ZSH_PERF_SPANS=()

if ! sysopen -a -o cloexec,creat -m 600 -u _ZSH_PERF_FD "$ZSH_PERF_LOG" 2>/dev/null; then
	unset _ZSH_PERF_ACTIVE
	return 1
fi

_zsh_perf_clean() {
	REPLY="${1//$'\t'/ }"
	REPLY="${REPLY//$'\n'/ }"
	REPLY="${REPLY//$'\r'/ }"
}

_zsh_perf_log() {
	local event="$1"
	local duration_ms="$2"
	local detail="${3:-}"

	_zsh_perf_clean "$detail"
	print -r -u "$_ZSH_PERF_FD" -- \
		"${EPOCHREALTIME}"$'\t'"$$"$'\t'"$event"$'\t'"$duration_ms"$'\t'"$REPLY"
}

_zsh_perf_elapsed_ms() {
	local started_at="$1"
	printf -v REPLY '%.3f' "$(( (EPOCHREALTIME - started_at) * 1000 ))"
}

_zsh_perf_source() {
	local label="$1"
	local source_path="$2"
	local started_at="$EPOCHREALTIME"
	local source_status

	builtin source "$source_path"
	source_status=$?
	_zsh_perf_elapsed_ms "$started_at"
	_zsh_perf_log source "$REPLY" "name=$label status=$source_status path=$source_path"
	return "$source_status"
}

_zsh_perf_begin() {
	_ZSH_PERF_SPANS[$1]="$EPOCHREALTIME"
}

_zsh_perf_end() {
	local label="$1"
	local started_at="${_ZSH_PERF_SPANS[$label]:-}"

	[[ -n "$started_at" ]] || return 0
	unset "_ZSH_PERF_SPANS[$label]"
	_zsh_perf_elapsed_ms "$started_at"
	_zsh_perf_log span "$REPLY" "name=$label"
}

_zsh_perf_preexec() {
	local command_word
	local -a command_words

	_ZSH_PERF_COMMAND_START="$EPOCHREALTIME"
	_ZSH_PERF_COMMAND_PWD="$PWD"
	if [[ -n "${ZSH_PERF_COMMAND_TEXT:-}" ]]; then
		_ZSH_PERF_COMMAND="$1"
		return 0
	fi

	_ZSH_PERF_COMMAND=unknown
	command_words=("${(z)1}")
	for command_word in "${command_words[@]}"; do
		[[ "$command_word" =~ '^[A-Za-z_][A-Za-z0-9_]*=' ]] && continue
		_ZSH_PERF_COMMAND="$command_word"
		break
	done
}

_zsh_perf_chpwd() {
	local duration_ms

	[[ -n "$_ZSH_PERF_COMMAND_START" ]] || return 0
	_zsh_perf_elapsed_ms "$_ZSH_PERF_COMMAND_START"
	duration_ms="$REPLY"
	(( duration_ms >= ZSH_PERF_MIN_MS )) || return 0
	_zsh_perf_log chpwd "$duration_ms" \
		"from=$_ZSH_PERF_COMMAND_PWD to=$PWD command=$_ZSH_PERF_COMMAND"
}

_zsh_perf_precmd() {
	local duration_ms
	local cwd_changed=0

	if (( ! _ZSH_PERF_STARTUP_LOGGED )); then
		_ZSH_PERF_STARTUP_LOGGED=1
		_zsh_perf_elapsed_ms "$_ZSH_PERF_SHELL_START"
		_zsh_perf_log startup "$REPLY" "cwd=$PWD shlvl=$SHLVL"
	fi

	[[ -n "$_ZSH_PERF_COMMAND_START" ]] || return 0
	_zsh_perf_elapsed_ms "$_ZSH_PERF_COMMAND_START"
	duration_ms="$REPLY"
	[[ "$PWD" == "$_ZSH_PERF_COMMAND_PWD" ]] || cwd_changed=1

	if (( duration_ms >= ZSH_PERF_MIN_MS )); then
		_zsh_perf_log command "$duration_ms" \
			"cwd_changed=$cwd_changed cwd=$PWD command=$_ZSH_PERF_COMMAND"
	fi

	_ZSH_PERF_COMMAND_START=''
	_ZSH_PERF_COMMAND_PWD=''
	_ZSH_PERF_COMMAND=''
}

_zsh_perf_install_hooks() {
	local duration_ms

	_zsh_perf_elapsed_ms "$_ZSH_PERF_SHELL_START"
	duration_ms="$REPLY"
	_zsh_perf_log zshrc "$duration_ms" "cwd=$PWD shlvl=$SHLVL"

	autoload -Uz add-zsh-hook
	add-zsh-hook -d preexec _zsh_perf_preexec 2>/dev/null
	add-zsh-hook -d chpwd _zsh_perf_chpwd 2>/dev/null
	add-zsh-hook -d precmd _zsh_perf_precmd 2>/dev/null
	add-zsh-hook preexec _zsh_perf_preexec
	add-zsh-hook chpwd _zsh_perf_chpwd
	add-zsh-hook precmd _zsh_perf_precmd
}

_zsh_perf_log session_start 0 "cwd=$PWD shlvl=$SHLVL interactive=$options[interactive]"
