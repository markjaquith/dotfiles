#!/usr/bin/env zsh
# Bulk pip and uv tool install

# sed succeeds even when quiet pip produces no non-deprecation output.
pip install --quiet \
	faker 2>&1 | sed '/DEPRECATION/d'

# Replace an existing jrnl executable, including one installed by pipx.
# Keep stderr visible so installation failures include the underlying error.
uv tool install --quiet --force jrnl
