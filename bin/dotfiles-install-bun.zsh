#!/usr/bin/env zsh
# Upgrade and install Bun packages (bulk)
bun upgrade > /dev/null 2>&1
bun i -g --no-summary \
    typescript@latest \
    typescript-language-server@latest \
    svelte-language-server@latest \
    oxfmt@latest \
    opencode-ai@latest \
    @tailwindcss/language-server@latest \
    vscode-langservers-extracted@latest \
    @astrojs/language-server@latest \
    bash-language-server@latest
