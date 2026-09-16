#!/usr/bin/env zsh
# Bulk Homebrew install

# Reserve the fx command for the fx.sh harness.
if brew list --formula fx &>/dev/null; then
	brew uninstall --quiet fx
fi

brew install --quiet \
    ack \
    btop \
    asciinema \
    gpg \
    zinit \
		bruno \
		bacon \
		jq \
		kondo \
		yamlfix \
		pkl-lsp \
		fswatch \
		git-filter-repo \
		watchman \
    buildkite/buildkite/bk@3 \
    stow \
    sesh \
    httpie \
    ghostscript \
    openscad \
    swiftbar \
    libyaml \
		terminal-notifier \
		switchaudio-osx \
		mole \
		aerc \
		w3m \
		markjaquith/tap/cowtree \
		tokei \
		trash

brew install --quiet --cask espanso
