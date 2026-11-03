#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/rex-settings-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/home/.config/rex"
cp "$repo_root/home/.config/rex/preferences.json" "$test_root/preferences.json"
ln -s "$test_root/preferences.json" "$test_root/home/.config/rex/preferences.json"

cat > "$test_root/bin/defaults" <<'MOCK'
#!/usr/bin/env zsh
if [[ "$1" == write ]]; then
	print -r -- "$*" >> "$REX_TEST_WRITES"
	exit 0
fi
[[ $# == 2 ]] && exit 0
case "$3" in
	Workspace.terminalFontName) print -r -- 'Test Font' ;;
	Workspace.usesStandardInactiveWindowPaneStyles) print 0 ;;
	*) exit 1 ;;
esac
MOCK
cat > "$test_root/bin/pgrep" <<'MOCK'
#!/usr/bin/env zsh
exit "${REX_TEST_RUNNING:-1}"
MOCK
cat > "$test_root/bin/uname" <<'MOCK'
#!/usr/bin/env zsh
print Darwin
MOCK
chmod +x "$test_root/bin/"*
export HOME="$test_root/home" PATH="$test_root/bin:$PATH"
export REX_TEST_WRITES="$test_root/writes"

zsh "$repo_root/bin/rex-settings" check
zsh "$repo_root/bin/rex-settings" apply
[[ $(wc -l < "$REX_TEST_WRITES") -eq 6 ]]
grep -q -- 'Workspace.usesStandardInactiveWindowPaneStyles -bool true' "$REX_TEST_WRITES"

export REX_TEST_RUNNING=0
if zsh "$repo_root/bin/rex-settings" apply >/dev/null 2>&1; then
	print -u2 -- 'FAIL: apply allowed while Rex was running'
	exit 1
fi
[[ $(wc -l < "$REX_TEST_WRITES") -eq 6 ]]
unset REX_TEST_RUNNING

jq '. + {"rex.client.label": "device-specific"}' "$test_root/preferences.json" > "$test_root/bad.json"
cat "$test_root/bad.json" > "$test_root/preferences.json"
if zsh "$repo_root/bin/rex-settings" apply >/dev/null 2>&1; then
	print -u2 -- 'FAIL: accepted a device-specific key'
	exit 1
fi
[[ $(wc -l < "$REX_TEST_WRITES") -eq 6 ]]

print '{"Workspace.usesStandardInactiveWindowPaneStyles":"true"}' > "$test_root/preferences.json"
if zsh "$repo_root/bin/rex-settings" check >/dev/null 2>&1; then
	print -u2 -- 'FAIL: accepted a mistyped boolean'
	exit 1
fi

zsh "$repo_root/bin/rex-settings" capture
[[ -L "$HOME/.config/rex/preferences.json" ]]
jq -e '. == {"Workspace.terminalFontName": "Test Font", "Workspace.usesStandardInactiveWindowPaneStyles": false}' "$test_root/preferences.json" >/dev/null
zsh "$repo_root/bin/rex-settings" check
zsh "$repo_root/bin/rex-settings" apply
[[ $(wc -l < "$REX_TEST_WRITES") -eq 8 ]]
grep -q -- 'Workspace.usesStandardInactiveWindowPaneStyles -bool false' "$REX_TEST_WRITES"

print -- 'rex-settings tests passed'
