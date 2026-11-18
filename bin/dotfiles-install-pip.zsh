#!/usr/bin/env zsh
# Bulk pip and uv tool install

# sed succeeds even when quiet pip produces no non-deprecation output.
pip install --quiet \
	faker 2>&1 | sed '/DEPRECATION/d'

# Replace an existing jrnl executable, including one installed by pipx.
# Keep stderr visible so installation failures include the underlying error.
uv tool install --quiet --force jrnl

# Agentodon is developed as a standalone local package, not vendored dotfiles.
typeset agentodon_source="${AGENTODON_SOURCE:-$HOME/Dev/agentodon}"
if [[ -f "$agentodon_source/pyproject.toml" ]]; then
	uv tool install --quiet --editable "$agentodon_source" || exit $?
	typeset agentodon_bin="$(uv tool dir --bin)/agentodon"
	"$agentodon_bin" setup --no-reload || exit $?
fi
