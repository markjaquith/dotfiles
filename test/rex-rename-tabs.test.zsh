#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/rex-rename-tabs-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

task_dir=$tmp_dir/tasks/abc-123
mkdir -p "$task_dir/code" "$tmp_dir/other" "$tmp_dir/bin"
: >"$task_dir/TASK.md"
log=$tmp_dir/log

cat >"$tmp_dir/bin/rex" <<MOCK
#!/usr/bin/env zsh
[[ \$1 == --autostart=false ]] || { print -u2 "missing --autostart=false"; exit 9 }
shift
case "\$1 \$2" in
	"whoami ") exit 0 ;;
	"ls --json") print -r -- '{"sessions":[{"session_id":"session:s1"}]}' ;;
	"api call")
		print -r -- '{"windows":[
			{"window_id":"window:w1","label":"Work","layers":[{"blocks":[{"block_id":"block:agents"},{"block_id":"block:b1"}]},{"blocks":[{"block_id":"block:b2"}]}]},
			{"window_id":"window:w2","label":"Plain","layers":[{"blocks":[{"block_id":"block:b3"}]}]}]}'
		;;
	"block call")
		case "\$6" in
			block:b1) print -r -- '{"foreground":{"cwd":"$task_dir/code"}}' ;;
			block:b2) print -r -- '{"child":{"cwd":"$task_dir"}}' ;;
			block:b3) print -r -- '{"foreground":{"cwd":"$tmp_dir/other"}}' ;;
			*) print -r -- '{}' ;;
		esac
		;;
	"window rename") print -r -- "rename \$4 \$5 \$6" >>"$log" ;;
	*) print -u2 "unexpected: \$*"; exit 9 ;;
esac
MOCK

cat >"$tmp_dir/bin/agency" <<MOCK
#!/usr/bin/env zsh
print -r -- "agency \$*" >>"$log"
print -r -- '{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"working","ticketUrl":"https://x.atlassian.net/browse/ABC-123"}}},"pr":{"url":"https://github.com/o/r/pull/1","draft":true}}}'
MOCK
chmod +x "$tmp_dir/bin/rex" "$tmp_dir/bin/agency"

: >"$log"
output=$(env -i HOME="$HOME" PATH="$tmp_dir/bin:$PATH" TMPDIR="$tmp_dir" \
	REX_RENAME_TABS_REX_BIN="$tmp_dir/bin/rex" zsh "$repo_root/bin/rex-rename-tabs")

actual_log=$(<"$log")
# Glyphs come from herdr-rename-tabs, whose own tests check them exactly.
[[ $(grep -c '^agency context ' "$log") == 1 ]] || {
	print -ru2 -- "FAIL: expected one cached agency lookup"; print -ru2 -- "$actual_log"; exit 1
}
[[ $(grep -c '^rename ' "$log") == 1 ]] || {
	print -ru2 -- "FAIL: expected only the Agency tab to be renamed"; print -ru2 -- "$actual_log"; exit 1
}
[[ $actual_log == *"rename session:s1 window:w1 "*" ABC-123 Work" ]] || {
	print -ru2 -- "FAIL: unexpected rename"; print -ru2 -- "$actual_log"; exit 1
}
[[ $output == "Work -> "*"ABC-123 Work" ]] || { print -ru2 -- "FAIL: output $output"; exit 1 }

# A missing Rex server is a silent no-op, not a server start.
cat >"$tmp_dir/bin/rex" <<'MOCK'
#!/usr/bin/env zsh
[[ $1 == --autostart=false ]] || exit 9
exit 4
MOCK
env -i HOME="$HOME" PATH="$tmp_dir/bin:$PATH" TMPDIR="$tmp_dir" \
	REX_RENAME_TABS_REX_BIN="$tmp_dir/bin/rex" zsh "$repo_root/bin/rex-rename-tabs"

print -r -- 'rex rename tab tests passed'
