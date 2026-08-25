DIR=$(dirname "$0")
┃() {
	if (( $+functions[_zsh_perf_source] )); then
		_zsh_perf_source "$1" "$DIR/$1.zsh"
	else
		builtin source "$DIR/$1.zsh"
	fi
}
