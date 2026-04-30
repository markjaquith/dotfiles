#!/usr/bin/env zsh

set -e

# Local copy of the framecap installer from https://framecap.app/install.
# Keep this local so dotfiles-install never pipes a live remote script into a shell.

BASE_URL="${FRAMECAP_URL:-https://assets.framecap.app}"
INSTALL_DIR="/usr/local/bin"

if [[ "$OSTYPE" != darwin* ]]; then
	exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

curl -fsSL "$BASE_URL/latest/framecap" -o "$TEMP_DIR/framecap"

curl -fsSL "$BASE_URL/latest/checksums.txt" -o "$TEMP_DIR/checksums.txt"
(
	cd "$TEMP_DIR"
	shasum -a 256 -c checksums.txt >/dev/null 2>&1
)

chmod +x "$TEMP_DIR/framecap"

if [[ ! -d "$INSTALL_DIR" ]]; then
	sudo mkdir -p "$INSTALL_DIR"
fi

if [[ -w "$INSTALL_DIR" ]]; then
	mv "$TEMP_DIR/framecap" "$INSTALL_DIR/framecap"
else
	sudo mv "$TEMP_DIR/framecap" "$INSTALL_DIR/framecap"
fi
