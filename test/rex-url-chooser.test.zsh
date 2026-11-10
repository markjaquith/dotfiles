#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/rex-url-chooser-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/rex" <<'MOCK'
#!/usr/bin/env zsh
[[ $1 == --autostart=false ]] || exit 9
[[ "$*" == *" -s session:s -b block:b "* || "$*" == *" -s session:s -b block:b" ]] || exit 8
case "$2" in
	block) print -r -- '{"columns":30,"rows":24}' ;;
	capture) print -r -- "$REX_TEST_SCREEN" ;;
	*) exit 7 ;;
esac
MOCK
cat >"$tmp_dir/bin/open" <<MOCK
#!/bin/sh
printf '%s\n' "\$*" >>"$tmp_dir/opened"
MOCK
cat >"$tmp_dir/bin/pbcopy" <<MOCK
#!/bin/sh
cat >>"$tmp_dir/copied"
MOCK
cat >"$tmp_dir/bin/fzf" <<MOCK
#!/bin/sh
cat >"$tmp_dir/candidates"
printf '%s\n%s\n' "\$REX_TEST_KEY" "\$REX_TEST_PICK"
MOCK
chmod +x "$tmp_dir/bin/"*

run() {
	rm -f "$tmp_dir/opened" "$tmp_dir/copied" "$tmp_dir/candidates"
	env PATH="$tmp_dir/bin:$PATH" REX_URL_CHOOSER_REX_BIN="$tmp_dir/bin/rex" \
		REX_URL_CHOOSER_OPEN="$tmp_dir/bin/open" REX_URL_CHOOSER_COPY="$tmp_dir/bin/pbcopy" \
		"$@" bash "$repo_root/bin/rex-url-chooser" session:s block:b </dev/null
}

fail() {
	print -ru2 -- "FAIL: $*"
	exit 1
}

run REX_TEST_SCREEN='done: https://example.com/a.' >/dev/null
[[ $(<"$tmp_dir/opened") == https://example.com/a ]] || fail 'single URL opens directly'
[[ ! -e $tmp_dir/candidates ]] || fail 'single URL skips the picker'

screen=$'see https://example.com/one, and (https://github.com/o/r/pull/12).\nhttps://example.com/one'
run REX_TEST_SCREEN="$screen" REX_TEST_KEY='' REX_TEST_PICK='https://github.com/o/r/pull/12'
[[ $(<"$tmp_dir/candidates") == $'https://example.com/one\nhttps://github.com/o/r/pull/12' ]] \
	|| fail "candidates: $(<"$tmp_dir/candidates")"
[[ $(<"$tmp_dir/opened") == https://github.com/o/r/pull/12 ]] || fail 'enter opens the pick'

run REX_TEST_SCREEN="$screen" REX_TEST_KEY=y REX_TEST_PICK='https://example.com/one'
[[ $(<"$tmp_dir/copied") == https://example.com/one && ! -e $tmp_dir/opened ]] || fail 'y copies'

# A program's hard wrap at the 30-column terminal width is rejoined.
run REX_TEST_SCREEN=$'https://example.com/aaaaaaaaaaa\nbbbb rest' >/dev/null
[[ $(<"$tmp_dir/opened") == https://example.com/aaaaaaaaaaabbbb ]] \
	|| fail "hard wrap: $(<"$tmp_dir/opened")"

output=$(run REX_TEST_SCREEN='no links here' || true)
[[ $output == 'No URLs detected'* ]] || fail 'no URLs message'

print -r -- 'rex url chooser tests passed'
