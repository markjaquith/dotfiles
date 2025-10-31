#!/usr/bin/env zsh
# Bulk pip and pipx install

pip install --quiet \
    faker 2>&1 | grep -v "DEPRECATION"

# pipx installs
pipx install --force jrnl > /dev/null 2>&1
