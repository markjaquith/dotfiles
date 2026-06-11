# Set the editor to Neovim, unless it doesn't exist, in which case use vim.
export EDITOR=nvim
if ! command -v nvim >/dev/null 2>&1; then
  export EDITOR=vim
fi

# Keychain secret helpers for macOS generic-password entries.
# `kc` reads a secret from Keychain; `kcs` writes or updates one.
kc() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: kc <service>"
    echo "Reads a generic-password secret from the macOS Keychain."
    return 0
  fi

  if [[ $# -ne 1 ]]; then
    echo "Usage: kc <service>"
    return 1
  fi

  security find-generic-password -a "$USER" -s "$1" -w 2>/dev/null
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
