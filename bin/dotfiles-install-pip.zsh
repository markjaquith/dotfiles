#!/usr/bin/env zsh
# Bulk pip and uv tool install

pip install --quiet \
    faker 2>&1 | grep -v "DEPRECATION"

# uv tool installs
uv tool install jrnl > /dev/null 2>&1
