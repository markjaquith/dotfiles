#!/usr/bin/env zsh

set -e

# Local copy of the framecap installer from https://framecap.app/install.
# Keep this local so dotfiles-install never pipes a live remote script into a shell.

BASE_URL="${FRAMECAP_URL:-https://assets.framecap.app}"
VERSION="${FRAMECAP_VERSION:-latest}"
SKIP_CHECKSUM="${FRAMECAP_SKIP_CHECKSUM:-0}"
INSTALL_DIR="/usr/local/bin"

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
CYAN='\033[36m'
GRAY='\033[90m'

error() {
	print -u2 "${RED}x${RESET} $1"
	exit 1
}

success() {
	print "${GREEN}+${RESET} $1"
}

if [[ "$OSTYPE" != darwin* ]]; then
	error "framecap only supports macOS"
fi

print "${BOLD}${CYAN}framecap${RESET} installer"
print ""

YEAR="$(date +%Y)"
print "${GRAY}------------------------------------------------------------${RESET}"
print "Copyright (c) $YEAR Stephen Tenuto"
print ""
print "This software requires a license for use."
print "Purchase a license at: framecap.app"
print ""
print "You may not redistribute it, wrap it in another app, or sell it in any form."
print "All other rights are reserved."
print "${GRAY}------------------------------------------------------------${RESET}"
print ""

if [[ "$VERSION" == "latest" ]]; then
	DOWNLOAD_URL="$BASE_URL/latest/framecap"
	CHECKSUM_URL="$BASE_URL/latest/checksums.txt"
	VERSION_NUM="$(curl -fsSL "$BASE_URL/latest/version.txt" 2>/dev/null || print "latest")"
	print "-> Installing version ${DIM}$VERSION_NUM${RESET}"
else
	[[ "$VERSION" == v* ]] || VERSION="v$VERSION"
	DOWNLOAD_URL="$BASE_URL/$VERSION/framecap"
	CHECKSUM_URL="$BASE_URL/$VERSION/checksums.txt"
	print "-> Installing version ${DIM}${VERSION#v}${RESET}"
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

print "-> Downloading..."
curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/framecap" || error "Download failed"

if [[ "$SKIP_CHECKSUM" == "0" ]]; then
	if curl -fsSL "$CHECKSUM_URL" -o "$TEMP_DIR/checksums.txt" 2>/dev/null; then
		(
			cd "$TEMP_DIR"
			shasum -a 256 -c checksums.txt >/dev/null 2>&1
		) || error "Checksum verification failed"
	fi
fi

chmod +x "$TEMP_DIR/framecap"

if [[ ! -d "$INSTALL_DIR" ]]; then
	sudo mkdir -p "$INSTALL_DIR"
fi

if [[ -w "$INSTALL_DIR" ]]; then
	mv "$TEMP_DIR/framecap" "$INSTALL_DIR/framecap"
else
	print "-> Installing to $INSTALL_DIR ${DIM}(requires password)${RESET}"
	sudo mv "$TEMP_DIR/framecap" "$INSTALL_DIR/framecap"
fi

print ""
if [[ "$VERSION" == "latest" ]]; then
	success "Installed framecap $VERSION_NUM"
else
	success "Installed framecap ${VERSION#v}"
fi
print ""
print "${DIM}Run 'framecap --help' to get started${RESET}"
