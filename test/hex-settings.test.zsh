#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/hex-settings-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/home/.config/hex" \
	"$test_root/home/Library/Application Support/hex"
cp "$repo_root/home/.config/hex/portable.jq" "$test_root/home/.config/hex/"
cp "$repo_root/home/.config/hex/preferences.json" "$test_root/preferences.json"
ln -s "$test_root/preferences.json" "$test_root/home/.config/hex/preferences.json"
cat > "$test_root/bin/pgrep" <<'MOCK'
#!/usr/bin/env zsh
exit "${HEX_TEST_RUNNING:-1}"
MOCK
cat > "$test_root/bin/uname" <<'MOCK'
#!/usr/bin/env zsh
print Darwin
MOCK
chmod +x "$test_root/bin/"*
export HOME="$test_root/home" PATH="$test_root/bin:$PATH"
live_file="$HOME/Library/Application Support/hex/settings.json"
config_file="$HOME/.config/hex/preferences.json"

zsh "$repo_root/bin/hex-settings" check
print '{"microphone":"local mic","migrations":["local"],"capture":{"folder":"/local","routing":{"jevApiKey":"test-only"}},"meetings":{"calendar":{"connected":true}},"sound_effects":false}' > "$live_file"
zsh "$repo_root/bin/hex-settings" apply
jq -e '.microphone == "local mic" and .migrations == ["local"] and
	.capture.folder == "/local" and .capture.routing.jevApiKey == "test-only" and
	.meetings.calendar.connected and .sound_effects' "$live_file" >/dev/null

cp "$live_file" "$test_root/before.json"
export HEX_TEST_RUNNING=0
if zsh "$repo_root/bin/hex-settings" apply >/dev/null 2>&1; then
	print -u2 -- 'FAIL: apply allowed while Hex was running'
	exit 1
fi
cmp "$live_file" "$test_root/before.json"
unset HEX_TEST_RUNNING

for bad in '{"microphone":"device"}' '{"capture":{"routing":{"jevApiKey":"secret"}}}' \
	'{"sound_effects":"true"}' '{"sound_effects":null}' '{"labs":{"future_flag":true}}'; do
	print -r -- "$bad" > "$config_file"
	if zsh "$repo_root/bin/hex-settings" apply >/dev/null 2>&1; then
		print -u2 -- "FAIL: accepted $bad"
		exit 1
	fi
	cmp "$live_file" "$test_root/before.json"
done

zsh "$repo_root/bin/hex-settings" capture
[[ -L "$config_file" ]]
jq -e 'has("microphone") == false and has("migrations") == false and
	(.capture | has("routing") == false and has("folder") == false) and
	(.meetings.calendar | has("connected") == false)' "$config_file" >/dev/null
zsh "$repo_root/bin/hex-settings" check

# Missing preferences stay missing; arrays replace rather than concatenate.
print '{"vocabulary":[{"term":"shared"}]}' > "$config_file"
print '{"sound_effects":false,"vocabulary":[{"term":"local"}]}' > "$live_file"
zsh "$repo_root/bin/hex-settings" apply
jq -e '.sound_effects == false and .vocabulary == [{"term":"shared"}]' "$live_file" >/dev/null
rm "$live_file"
zsh "$repo_root/bin/hex-settings" apply
cmp "$config_file" "$live_file"

# Invalid local JSON is not overwritten.
print '{broken' > "$live_file"
if zsh "$repo_root/bin/hex-settings" apply >/dev/null 2>&1; then
	print -u2 -- 'FAIL: overwrote malformed local settings'
	exit 1
fi
[[ "$(< "$live_file")" == '{broken' ]]
print -- 'hex-settings tests passed'
