#!/usr/bin/env zsh

set -eu
setopt pipefail

repo_root=${0:A:h:h}
script="$repo_root/bin/crontab-sync"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/crontab-sync-test.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT INT TERM

typeset -i test_count=0

fail() {
	print -u2 -- "FAIL: $*"
	exit 1
}

assert_contains() {
	local name=$1
	local haystack=$2
	local needle=$3
	(( ++test_count ))
	[[ "$haystack" == *"$needle"* ]] || fail "$name: missing ${(qqq)needle}"
}

assert_equal() {
	local name=$1
	local expected=$2
	local actual=$3
	(( ++test_count ))
	[[ "$actual" == "$expected" ]] || {
		print -u2 -- "FAIL: $name"
		print -u2 -- "expected: ${(qqq)expected}"
		print -u2 -- "actual:   ${(qqq)actual}"
		exit 1
	}
}

write_config() {
	cat >| "$temp_dir/jobs.json"
}

mkdir "$temp_dir/bin"
cat >| "$temp_dir/bin/crontab" <<'EOF'
#!/usr/bin/env zsh
if [[ "$1" == -l ]]; then
	if [[ -f "$CRONTAB_STORE" ]]; then
		cat "$CRONTAB_STORE"
		exit 0
	fi
	print -u2 "no crontab for test"
	exit 1
fi
if [[ "$1" == - ]]; then
	cat >| "$CRONTAB_STORE"
	exit 0
fi
exit 2
EOF
chmod +x "$temp_dir/bin/crontab"
export CRONTAB_STORE="$temp_dir/crontab"
export PATH="$temp_dir/bin:$PATH"

write_config <<'EOF'
{
	"jobs": [
		{
			"name": "backup",
			"description": "Back up documents",
			"schedule": "0 2 * * *",
			"command": "/usr/local/bin/backup"
		},
		{
			"name": "cleanup",
			"schedule": "@daily",
			"command": "/usr/local/bin/cleanup",
			"enabled": false
		}
	]
}
EOF

output=$("$script" check -f "$temp_dir/jobs.json")
assert_equal "valid config" "Valid: 2 job(s)" "$output"

output=$("$script" render -f "$temp_dir/jobs.json")
assert_contains "renders enabled job" "$output" "0 2 * * * /usr/local/bin/backup"
assert_contains "renders disabled job" "$output" "# DISABLED: @daily /usr/local/bin/cleanup"

printf '%s\n' "# manual job" "5 * * * * /usr/local/bin/manual" >| "$CRONTAB_STORE"
"$script" apply -f "$temp_dir/jobs.json" >/dev/null
first_apply=$(<"$CRONTAB_STORE")
assert_contains "preserves manual entry" "$first_apply" "5 * * * * /usr/local/bin/manual"
assert_contains "adds begin fence" "$first_apply" "# BEGIN crontab-sync managed section"
assert_contains "adds managed job" "$first_apply" "0 2 * * * /usr/local/bin/backup"

"$script" apply -f "$temp_dir/jobs.json" >/dev/null
second_apply=$(<"$CRONTAB_STORE")
assert_equal "apply is idempotent" "$first_apply" "$second_apply"

write_config <<'EOF'
{
	"jobs": [
		{"name": "same", "schedule": "0 1 * * *", "command": "one"},
		{"name": "same", "schedule": "0 2 * * *", "command": "two"}
	]
}
EOF
if "$script" check -f "$temp_dir/jobs.json" >| "$temp_dir/output" 2>&1; then
	fail "duplicate names accepted"
fi
assert_contains "rejects duplicate names" "$(<"$temp_dir/output")" "job names must be unique"

write_config <<'EOF'
{
	"jobs": [
		{"name": "bad", "schedule": "every day", "command": "nope"}
	]
}
EOF
if "$script" check -f "$temp_dir/jobs.json" >| "$temp_dir/output" 2>&1; then
	fail "invalid schedule accepted"
fi
assert_contains "rejects invalid schedule" "$(<"$temp_dir/output")" "five cron fields or a supported macro"

printf '%s\n' "manual" "# BEGIN crontab-sync managed section" >| "$CRONTAB_STORE"
if "$script" diff -f "$repo_root/home/.config/crontab/jobs.json" >| "$temp_dir/output" 2>&1; then
	fail "incomplete fences accepted"
fi
assert_contains "rejects incomplete fences" "$(<"$temp_dir/output")" "exactly one complete managed section"

print -r -- "$test_count crontab-sync tests passed"
