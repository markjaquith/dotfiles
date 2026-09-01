#!/usr/bin/env zsh
set -eo pipefail

repo_root=${0:A:h:h}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/keychain-secret-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

expected_pem="$test_root/expected.pem"
actual_pem="$test_root/actual.pem"
print -rn -- $'-----BEGIN CERTIFICATE-----\nsynthetic certificate text\n-----END CERTIFICATE-----\n' > "$expected_pem"

cat > "$test_root/security" <<'MOCK_SECURITY'
#!/usr/bin/env zsh

if [[ "$*" == *"-s multiline-service"* ]]; then
	print -rn -- "0x"
	xxd -p "$KC_TEST_PEM" | tr -d '\n'
	return 0
fi

if [[ "$*" == *"-s normal-service"* ]]; then
	print -rn -- "ordinary-secret"
	return 0
fi

return 1
MOCK_SECURITY
chmod +x "$test_root/security"

PATH="$test_root:$PATH"
export KC_TEST_PEM="$expected_pem"
USER="keychain-test-user"
source "$repo_root/home/.zsh/105-misc.zsh"

kc --decode-hex multiline-service > "$actual_pem"
if ! cmp -s "$expected_pem" "$actual_pem"; then
	print -ru2 -- "FAIL: multiline Keychain value did not round-trip"
	exit 1
fi

if [[ "$(kc --decode-hex multiline-service)" != $'-----BEGIN CERTIFICATE-----\nsynthetic certificate text\n-----END CERTIFICATE-----' ]]; then
	print -ru2 -- "FAIL: command substitution did not preserve internal newlines"
	exit 1
fi

if [[ "$(kc normal-service)" != "ordinary-secret" ]]; then
	print -ru2 -- "FAIL: normal Keychain value changed"
	exit 1
fi

print -r -- "keychain secret tests passed"
