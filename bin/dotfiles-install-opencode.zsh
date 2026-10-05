#!/usr/bin/env zsh

set -e
set -o pipefail

config_dir="${0:A:h:h}/home/.config/opencode"
if [[ -e "$config_dir/plugins/herdr-agent-state.js" ]]; then
	version=$(sed -n 's|^// HERDR_INTEGRATION_VERSION=||p' "$config_dir/plugins/herdr-agent-state.js")
	if [[ "$version" != <-> || "$version" -lt 12 ]]; then
		print -u2 "Herdr's server plugin needs integration version 12 or newer for OpenCode 2. Reinstall the V2-compatible Herdr integration."
		exit 1
	fi
fi
npm ci --ignore-scripts --prefix "$config_dir"

curl -fsSL https://opencode.ai/v2/install | bash
"$HOME/.opencode/bin/opencode" --version

# Remove only legacy V1 package artifacts, never binaries, sessions, credentials, or config.
legacy_dir="$HOME/.opencode"
if [[ -f "$legacy_dir/package.json" ]] && grep -q '"@opencode-ai/plugin"' "$legacy_dir/package.json"; then
	rm -rf "$legacy_dir/node_modules" "$legacy_dir/package-lock.json" "$legacy_dir/package.json"
fi
rm -f "$legacy_dir/OpenCode.zip"
