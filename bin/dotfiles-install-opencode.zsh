#!/usr/bin/env zsh

set -e

config_dir="${0:A:h:h}/home/.config/opencode"
if [[ -e "$config_dir/plugins/herdr-agent-state.js" ]]; then
	print -u2 "Herdr restored its legacy server plugin. Reconcile it with legacy-integrations before installing OpenCode 2."
	exit 1
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
