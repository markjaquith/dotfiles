#!/usr/bin/env zsh

set -e

config_dir="${0:A:h:h}/home/.config/opencode"
if [[ -e "$config_dir/plugins/herdr-agent-state.js" ]]; then
	version=$(sed -n 's|^// HERDR_INTEGRATION_VERSION=||p' "$config_dir/plugins/herdr-agent-state.js")
	if [[ "$version" != <-> || "$version" -lt 12 ]]; then
		print -u2 "Herdr's server plugin needs integration version 12 or newer for OpenCode 2. Reinstall the V2-compatible Herdr integration."
		exit 1
	fi
fi
npm ci --ignore-scripts --prefix "$config_dir"

bun install -g --trust @opencode-ai/cli@0.0.0-beta-19271
global_bin=$(bun pm bin -g)
"$global_bin/opencode2" --version
ln -sfn opencode2 "$global_bin/opencode"

# Remove only legacy V1 installer artifacts, never sessions, credentials, or config.
legacy_dir="$HOME/.opencode"
legacy_bin="$legacy_dir/bin/opencode"
if [[ -f "$legacy_bin" || -L "$legacy_bin" ]]; then
	rm "$legacy_bin"
fi
if [[ -f "$legacy_dir/package.json" ]] && grep -q '"@opencode-ai/plugin"' "$legacy_dir/package.json"; then
	rm -rf "$legacy_dir/node_modules" "$legacy_dir/package-lock.json" "$legacy_dir/package.json"
fi
rm -f "$legacy_dir/OpenCode.zip"
rmdir "$legacy_dir/bin" 2>/dev/null || true
rmdir "$legacy_dir" 2>/dev/null || true
