# Set the editor to Neovim, unless it doesn't exist, in which case use vim.
export EDITOR=nvim
if ! command -v nvim >/dev/null 2>&1; then
	export EDITOR=vim
fi

# Keychain secret helpers for macOS generic-password entries.
# `kc` reads a secret from Keychain; `kcs` writes or updates one.
kc() {
	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		echo "Usage: kc [--decode-hex] <service>"
		echo "Reads a generic-password secret from the macOS Keychain."
		return 0
	fi

	local decode_hex=0
	local service
	if [[ $# -eq 1 ]]; then
		service="$1"
	elif [[ $# -eq 2 && "$1" == "--decode-hex" ]]; then
		decode_hex=1
		service="$2"
	else
		echo "Usage: kc [--decode-hex] <service>"
		return 1
	fi

	if [[ "$decode_hex" == "0" ]]; then
		security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null
		return
	fi

	local encoded hex
	encoded="$(security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null)" || return 1
	hex="${encoded#0x}"
	if [[ -z "$hex" || ! "$hex" =~ '^[0-9A-Fa-f]+$' || $(( ${#hex} % 2 )) -ne 0 ]]; then
		print -u2 -- "kc: Keychain value is not valid hexadecimal output"
		return 1
	fi

	print -rn -- "$hex" | xxd -r -p
}

# Writes a generic-password secret to Keychain for this user account.
kcs() {
	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		echo "Usage: kcs <service> <secret>"
		echo "Writes or updates a generic-password secret in the macOS Keychain."
		return 0
	fi

	if [[ $# -ne 2 ]]; then
		echo "Usage: kcs <service> <secret>"
		return 1
	fi

	security add-generic-password -a "$USER" -s "$1" -w "$2" -U 2>/dev/null
}

alias kc=' kc'
alias kcs=' kcs'
