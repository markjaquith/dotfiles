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

bun install -g --trust @opencode-ai/cli@0.0.0-beta-19228
global_bin=$(bun pm bin -g)
"$global_bin/opencode2" --version
ln -sfn opencode2 "$global_bin/opencode"

# Remove only the legacy executable, never sessions, credentials, or config.
if [[ -f "$HOME/.opencode/bin/opencode" || -L "$HOME/.opencode/bin/opencode" ]]; then
	rm "$HOME/.opencode/bin/opencode"
fi
