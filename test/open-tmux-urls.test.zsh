#!/usr/bin/env zsh
set -eo pipefail

source .zsh/100-aliases.zsh

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

print -r -- "open-tmux-urls tests passed"
