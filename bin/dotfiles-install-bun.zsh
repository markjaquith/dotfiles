#!/usr/bin/env zsh
# Bun itself is managed by mise; install and update its global packages here.
bun i -g --no-summary \
    typescript@latest \
    typescript-language-server@latest \
    svelte-language-server@latest \
    oxfmt@latest \
    @tailwindcss/language-server@latest \
    vscode-langservers-extracted@latest \
		@astrojs/language-server@latest \
		bash-language-server@latest \
		diffity@latest \
		btca@latest \
		@markjaquith/agency@latest \
		@kitlangton/stack@latest \
		sideshow@latest
