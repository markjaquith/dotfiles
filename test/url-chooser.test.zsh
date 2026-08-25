#!/usr/bin/env zsh
set -eo pipefail

URL_CHOOSER_FUNCTIONS_ONLY=1
source .config/herdr/plugins/local/url-chooser/picker.sh
unset URL_CHOOSER_FUNCTIONS_ONLY

set -u

assert_urls() {
	local name="$1"
	local input="$2"
	local expected="$3"
	local actual

	actual=$(print -r -- "$input" | extract_urls || true)

	if [[ "$actual" != "$expected" ]]; then
		print -ru2 -- "FAIL: $name"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		return 1
	fi
}

assert_wrapped_urls() {
	local name="$1"
	local width="$2"
	local input="$3"
	local expected="$4"
	local actual

	actual=$(print -r -- "$input" | join_wrapped_urls "$width" | extract_urls || true)

	if [[ "$actual" != "$expected" ]]; then
		print -ru2 -- "FAIL: $name"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		return 1
	fi
}

assert_urls \
	"localhost with port" \
	"server at http://localhost:9595/" \
	"http://localhost:9595/"

assert_urls \
	"dotted hostname" \
	"see https://example.com/path" \
	"https://example.com/path"

assert_urls \
	"trailing punctuation" \
	"see https://example.com/path." \
	"https://example.com/path"

assert_urls \
	"markdown paren wrapper" \
	"[docs](https://example.com/path)" \
	"https://example.com/path"

assert_urls \
	"balanced path parens" \
	"see https://example.com/wiki/Salt_(chemistry)" \
	"https://example.com/wiki/Salt_(chemistry)"

assert_urls \
	"balanced path brackets" \
	"see https://example.com/a[b]c" \
	"https://example.com/a[b]c"

assert_urls \
	"extra closers and punctuation" \
	"see https://example.com/path))..." \
	"https://example.com/path"

assert_urls \
	"quote wrappers" \
	'"https://example.com/double" '\''https://example.com/single'\'' `https://example.com/code`' \
	$'https://example.com/code\nhttps://example.com/double\nhttps://example.com/single'

assert_wrapped_urls \
	"Pi-style hard-wrapped URL" \
	40 \
	$' https://example.com/abcdefghijklmnopq\n rstuvwxyz?x=1' \
	"https://example.com/abcdefghijklmnopqrstuvwxyz?x=1"

assert_wrapped_urls \
	"OpenCode diff gutter and parenthesized URL" \
	98 \
	$'  ┃    33 + Draft PR [Gusto/zenpayroll#369675](https://github.com/Gusto/zenpayroll/pull/\n  ┃         369675) contains four commits at head `572676269f99`.' \
	"https://github.com/Gusto/zenpayroll/pull/369675"

assert_wrapped_urls \
	"OpenCode prose indentation and parenthesized URL" \
	98 \
	$'     Created draft PR: Gusto/zenpayroll#369675 (https://github.com/Gusto/zenpayroll/pull/\n     369675)' \
	"https://github.com/Gusto/zenpayroll/pull/369675"

assert_wrapped_urls \
	"ordinary hard newline remains a boundary" \
	40 \
	$'https://example.com/path\nnext-line' \
	"https://example.com/path"

assert_wrapped_urls \
	"new URL is not treated as a continuation" \
	40 \
	$' https://example.com/abcdefghijklmnopq\nhttps://other.example/path' \
	$'https://example.com/abcdefghijklmnopq\nhttps://other.example/path'

assert_urls \
	"dedupes and sorts" \
	$'https://z.example/path\nhttps://a.example/path\nhttps://z.example/path' \
	$'https://a.example/path\nhttps://z.example/path'

assert_urls \
	"bare host without dot is ignored" \
	"not a match: http://not-localhost/" \
	""

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/url-chooser-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
mock_herdr="$tmp_dir/herdr"
args_file="$tmp_dir/args"

printf '%s\n' \
	'#!/usr/bin/env zsh' \
	'print -rl -- "$@" >"$URL_CHOOSER_ARGS_FILE"' \
	>"$mock_herdr"
chmod +x "$mock_herdr"

HERDR_BIN_PATH="$mock_herdr" \
	HERDR_PLUGIN_ID="url-chooser" \
	URL_CHOOSER_ARGS_FILE="$args_file" \
	HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_id":"w1:p2","focused_pane_cwd":"/tmp/url chooser"}' \
	bash .config/herdr/plugins/local/url-chooser/open.sh

assert_arg() {
	local expected="$1"

	if ! grep -Fxq -- "$expected" "$args_file"; then
		print -ru2 -- "FAIL: missing launcher argument ${(qqq)expected}"
		return 1
	fi
}

assert_arg "plugin"
assert_arg "pane"
assert_arg "open"
assert_arg "--plugin"
assert_arg "url-chooser"
assert_arg "--entrypoint"
assert_arg "picker"
assert_arg "--placement"
assert_arg "popup"
assert_arg "--cwd"
assert_arg "/tmp/url chooser"
assert_arg "--focus"
assert_arg "--env"
assert_arg "HERDR_URL_CHOOSER_TARGET_PANE=w1:p2"

if grep -Fxq -- "overlay" "$args_file"; then
	print -ru2 -- "FAIL: launcher still requests overlay placement"
	return 1
fi

cat >"$mock_herdr" <<'MOCK_HERDR'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
	"pane layout --pane w1:p2")
		printf '%s\n' '{"result":{"layout":{"panes":[{"pane_id":"w1:p2","rect":{"width":40,"height":10}}]}}}'
		;;
	"pane read w1:p2 --source recent-unwrapped --lines 10 --format text")
		if [[ "${URL_CHOOSER_MOCK_PLAIN:-}" == "1" ]]; then
			printf '%s\n' 'see https://plain.example/path'
		elif [[ "${URL_CHOOSER_MOCK_UNRELATED:-}" == "1" ]]; then
			printf '%s\n' \
				' https://example.com/abcdefghijklmnopq' \
				' UNRELATED'
		else
			printf '%s\n' \
				' https://example.com/abcdefghijklmnopq' \
				' rstuvwxyz?x=1'
		fi
		;;
	"pane get w1:p2")
		printf '{"result":{"pane":{"agent_session":{"value":"%s"}}}}\n' \
			"${URL_CHOOSER_MOCK_SESSION:-}"
		;;
	*)
		printf 'unexpected mock Herdr arguments: %s\n' "$*" >&2
		exit 1
		;;
esac
MOCK_HERDR

opened_file="$tmp_dir/opened"
fzf_input_file="$tmp_dir/fzf-input"
fzf_args_file="$tmp_dir/fzf-args"
cat >"$tmp_dir/open" <<'MOCK_OPEN'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$URL_CHOOSER_OPENED_FILE"
MOCK_OPEN
cat >"$tmp_dir/fzf" <<'MOCK_FZF'
#!/usr/bin/env bash
cat >"$URL_CHOOSER_FZF_INPUT_FILE"
printf '%s\n' "$@" >"$URL_CHOOSER_FZF_ARGS_FILE"
MOCK_FZF
chmod +x "$mock_herdr" "$tmp_dir/open" "$tmp_dir/fzf"

PATH="$tmp_dir:$PATH" \
	HERDR_BIN_PATH="$mock_herdr" \
	HERDR_URL_CHOOSER_TARGET_PANE="w1:p2" \
	URL_CHOOSER_OPENED_FILE="$opened_file" \
	URL_CHOOSER_FZF_INPUT_FILE="$fzf_input_file" \
	URL_CHOOSER_FZF_ARGS_FILE="$fzf_args_file" \
	bash .config/herdr/plugins/local/url-chooser/picker.sh || true

if [[ -e "$opened_file" ]]; then
	print -ru2 -- "FAIL: reconstructed URL opened without confirmation"
	return 1
fi

grep -Fxq -- "https://example.com/abcdefghijklmnopqrstuvwxyz?x=1" "$fzf_input_file"
grep -Fxq -- "--header=Wrapped URL candidate — verify before opening" "$fzf_args_file"

session_file="$tmp_dir/session.jsonl"
printf '%s\n' \
	'{"text":"https://example.com/abcdefghijklmnopq\nUNRELATED"}' \
	>"$session_file"
URL_CHOOSER_MOCK_UNRELATED=1 \
	URL_CHOOSER_MOCK_SESSION="$session_file" \
	PATH="$tmp_dir:$PATH" \
	HERDR_BIN_PATH="$mock_herdr" \
	HERDR_URL_CHOOSER_TARGET_PANE="w1:p2" \
	URL_CHOOSER_OPENED_FILE="$opened_file" \
	URL_CHOOSER_FZF_INPUT_FILE="$fzf_input_file" \
	URL_CHOOSER_FZF_ARGS_FILE="$fzf_args_file" \
	bash .config/herdr/plugins/local/url-chooser/picker.sh || true

if [[ -e "$opened_file" ]]; then
	print -ru2 -- "FAIL: URL joined to unrelated session line opened"
	return 1
fi

grep -Fxq -- "https://example.com/abcdefghijklmnopqUNRELATED" "$fzf_input_file"
grep -Fxq -- "--header=Wrapped URL candidate — verify before opening" "$fzf_args_file"

printf '%s\n' \
	'{"text":"https://example.com/abcdefghijklmnopqrstuvwxyz?x=1"}' \
	>"$session_file"
URL_CHOOSER_MOCK_SESSION="$session_file" \
	PATH="$tmp_dir:$PATH" \
	HERDR_BIN_PATH="$mock_herdr" \
	HERDR_URL_CHOOSER_TARGET_PANE="w1:p2" \
	URL_CHOOSER_OPENED_FILE="$opened_file" \
	bash .config/herdr/plugins/local/url-chooser/picker.sh

grep -Fxq -- "https://example.com/abcdefghijklmnopqrstuvwxyz?x=1" "$opened_file"

URL_CHOOSER_MOCK_PLAIN=1 \
	PATH="$tmp_dir:$PATH" \
	HERDR_BIN_PATH="$mock_herdr" \
	HERDR_URL_CHOOSER_TARGET_PANE="w1:p2" \
	URL_CHOOSER_OPENED_FILE="$opened_file" \
	bash .config/herdr/plugins/local/url-chooser/picker.sh

grep -Fxq -- "https://plain.example/path" "$opened_file"

grep -Fxq -- 'placement = "popup"' .config/herdr/plugins/local/url-chooser/herdr-plugin.toml
grep -Fxq -- 'width = "80%"' .config/herdr/plugins/local/url-chooser/herdr-plugin.toml

print -r -- "url-chooser tests passed"
