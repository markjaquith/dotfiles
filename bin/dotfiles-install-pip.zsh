#!/usr/bin/env zsh
# Bulk pip and pipx install

pip install --quiet \
    faker

# pipx installs
pipx install --force jrnl > /dev/null 2>&1
