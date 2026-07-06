#!/usr/bin/env zsh

if ! command -v mise &> /dev/null
then
	echo "Installing mise..."
	brew install mise
elif brew list --formula mise &> /dev/null
then
	echo "Updating mise..."
	brew upgrade mise
fi

# Install mise tools globally
mise use -g herdr@latest > /dev/null
mise use hk@latest > /dev/null
mise use pkl@latest > /dev/null

herdr_plugins=(
	paulbkim-dev/vim-herdr-navigation
	devashish2203/herdr-worktrunk
)

for plugin in "${herdr_plugins[@]}"; do
	if command -v herdr &> /dev/null; then
		herdr plugin install "$plugin" --yes > /dev/null
	else
		mise exec -- herdr plugin install "$plugin" --yes > /dev/null
	fi
done

local_herdr_plugins=(
	"${SCRIPT_DIR}/../.config/herdr/plugins/local/url-chooser"
)

for plugin in "${local_herdr_plugins[@]}"; do
	if command -v herdr &> /dev/null; then
		herdr plugin link "$plugin" > /dev/null
	else
		mise exec -- herdr plugin link "$plugin" > /dev/null
	fi
done
