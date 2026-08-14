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

grep -Fxq -- 'placement = "popup"' .config/herdr/plugins/local/url-chooser/herdr-plugin.toml
grep -Fxq -- 'width = "80%"' .config/herdr/plugins/local/url-chooser/herdr-plugin.toml

print -r -- "url-chooser tests passed"
