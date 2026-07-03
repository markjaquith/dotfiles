#!/usr/bin/env zsh

if ! command -v mise &> /dev/null
then
	echo "Installing mise..."
	brew install mise
fi

# Install mise tools globally
mise use -g herdr@latest > /dev/null
mise use hk@latest > /dev/null
mise use pkl@latest > /dev/null
