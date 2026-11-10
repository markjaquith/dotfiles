#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
HERDR_RENAME_TABS_FUNCTIONS_ONLY=1
source "$repo_root/bin/herdr-rename-tabs"
unset HERDR_RENAME_TABS_FUNCTIONS_ONLY
set -u

typeset -i test_count=0

assert_indicators() {
	local name=$1
	local context_json=$2
	local expected=$3
	local actual

	actual=$(indicators_from_context <<< "$context_json")
	(( ++test_count ))
	if [[ $actual != $expected ]]; then
		print -ru2 -- "FAIL: $name"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		return 1
	fi
}

assert_label() {
	local name=$1
	local existing_label=$2
	local pr_status=$3
	local jira_ticket=$4
	local expected=$5
	local actual

	format_tab_label "$existing_label" "$pr_status" "$jira_ticket"
	actual=$REPLY
	(( ++test_count ))
	if [[ $actual != $expected ]]; then
		print -ru2 -- "FAIL: $name"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		return 1
	fi

	format_tab_label "$actual" "$pr_status" "$jira_ticket"
	actual=$REPLY
	(( ++test_count ))
	if [[ $actual != $expected ]]; then
		print -ru2 -- "FAIL: $name is not idempotent"
		print -ru2 -- "expected: ${(qqq)expected}"
		print -ru2 -- "actual:   ${(qqq)actual}"
		return 1
	fi
}

assert_label "plain title" \
	"Ordinary work" none "" \
	"Ordinary work"
assert_label "Jira key embedded in title" \
	"blah FOO-1234 blah" none "" \
	"blah  FOO-1234 blah"
assert_label "existing embedded Jira glyph" \
	"blah  FOO-1234 blah" none "" \
	"blah  FOO-1234 blah"
assert_label "invalid Jira leading zero" \
	"FOO-023 invalid" none "" \
	"FOO-023 invalid"
assert_label "invalid two-letter Jira project" \
	"AB-123 invalid" none "" \
	"AB-123 invalid"

assert_label "open PR" \
	"Work" open "" \
	" Work"
assert_label "draft PR" \
	"Work" draft "" \
	" Work"
assert_label "merged PR" \
	"Work" merged "" \
	" Work"
assert_label "draft replaces open" \
	" Work" draft "" \
	" Work"
assert_label "merged replaces draft" \
	" Work" merged "" \
	" Work"
assert_label "open replaces merged" \
	" Work" open "" \
	" Work"
assert_label "stale PR status removed" \
	" Work" none "" \
	"Work"

assert_label "Agency Jira ticket" \
	"Feed the penguins" none ABC-101 \
	" ABC-101 Feed the penguins"
assert_label "PR before Agency Jira ticket" \
	"Feed the penguins" draft ABC-101 \
	"  ABC-101 Feed the penguins"
assert_label "existing raw Jira key moved to front" \
	"Feed the ABC-101 penguins" open ABC-101 \
	"  ABC-101 Feed the penguins"
assert_label "existing Jira indicator moved after PR" \
	" ABC-101 Feed the penguins" merged ABC-101 \
	"  ABC-101 Feed the penguins"
assert_label "Agency Jira replaces old leading Jira" \
	" OLD-999 Feed the penguins" draft NEW-234 \
	"  NEW-234 Feed the penguins"
assert_label "Agency task ID title" \
	"ABC-314-clean-lion-enclosure" open ABC-314 \
	"$pr_glyph $jira_glyph ABC-314 clean-lion-enclosure"
assert_label "duplicated Agency task ID title" \
	"$pr_glyph $jira_glyph ABC-314 ABC-314-clean-lion-enclosure" open ABC-314 \
	"$pr_glyph $jira_glyph ABC-314 clean-lion-enclosure"
assert_label "longer ticket number is not stripped" \
	"ABC-3140-other" none ABC-314 \
	"$jira_glyph ABC-314 ABC-3140-other"
assert_label "ticket-only title" \
	"ABC-101" open ABC-101 \
	"  ABC-101"

assert_label "duplicate draft and Jira prefixes" \
	"    ABC-101 Otter enrichment" draft ABC-101 \
	"  ABC-101 Otter enrichment"
assert_label "duplicate prefixes without Jira ticket" \
	"   Secrets" draft "" \
	" Secrets"
assert_label "wrong PR and duplicate Jira prefixes" \
	"    ABC-102 Giraffe habitat" open ABC-102 \
	"  ABC-102 Giraffe habitat"

assert_indicators "working task without PR" \
	'{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"working","ticketUrl":null}}},"pr":{"url":null,"state":"none"}}}' \
	'{"prStatus":"","jiraTicket":""}'
assert_indicators "draft PR without ticket URL" \
	'{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"working","ticketUrl":null}}},"pr":{"url":"https://github.com/example/repo/pull/1","state":"open","draft":true,"merged":false}}}' \
	'{"prStatus":"draft","jiraTicket":""}'
assert_indicators "open PR and Jira URL" \
	'{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"working","ticketUrl":"https://jira.example/browse/ABC-101"}}},"pr":{"url":"https://github.com/example/repo/pull/1","state":"open","draft":false,"merged":false}}}' \
	'{"prStatus":"open","jiraTicket":"ABC-101"}'
assert_indicators "merged takes precedence over draft" \
	'{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"working","ticketUrl":null}}},"pr":{"draft":true,"merged":true}}}' \
	'{"prStatus":"merged","jiraTicket":""}'
assert_indicators "phase uses parent task Jira URL" \
	'{"result":{"target":{"kind":"phase"},"documents":{"task":{"data":{"status":"working","ticketUrl":"https://jira.example/browse/ABC-205"}},"phase":{"data":{"status":"working"}}},"pr":{"draft":true,"merged":false}}}' \
	'{"prStatus":"draft","jiraTicket":"ABC-205"}'
assert_indicators "non-working task has no PR status" \
	'{"result":{"target":{"kind":"task"},"documents":{"task":{"data":{"status":"done","ticketUrl":"https://jira.example/browse/ABC-101"}}},"pr":{"draft":false,"merged":true}}}' \
	'{"prStatus":"","jiraTicket":"ABC-101"}'
assert_indicators "unrelated Agency target ignored" \
	'{"result":{"target":{"kind":"epic"},"documents":{"task":null},"pr":null}}' \
	''

if format_tab_label "Work" unexpected "" >/dev/null 2>&1; then
	print -ru2 -- "FAIL: invalid PR status was accepted"
	exit 1
fi
(( ++test_count ))

print -r -- "$test_count herdr rename tab tests passed"
