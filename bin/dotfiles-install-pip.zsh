#!/usr/bin/env zsh
# Bulk pip and uv tool install

# sed succeeds even when quiet pip produces no non-deprecation output.
pip install --quiet \
	faker 2>&1 | sed '/DEPRECATION/d'

# uv tool installs
uv tool install jrnl > /dev/null 2>&1
