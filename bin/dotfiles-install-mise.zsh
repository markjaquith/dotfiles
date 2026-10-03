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
mise use -g herdr@0.8.2 > /dev/null
mise use hk@latest > /dev/null
mise use -g pi@latest > /dev/null

# Install Pi's structured question dialog for personal sessions.
if command -v pi &> /dev/null; then
	pi install npm:@juicesharp/rpiv-ask-user-question
else
	mise exec -- pi install npm:@juicesharp/rpiv-ask-user-question
fi
mise use -g pnpm@latest > /dev/null
mise use -g fzf@latest > /dev/null
mise use pkl@latest > /dev/null

herdr_plugins=(
	paulbkim-dev/vim-herdr-navigation
	amiramay/herdr-layout-cycle
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
	"${SCRIPT_DIR}/../home/.config/herdr/plugins/local"/*/herdr-plugin.toml(N)
)

for plugin_manifest in "${local_herdr_plugins[@]}"; do
	plugin="${plugin_manifest:h}"
	if command -v herdr &> /dev/null; then
		herdr plugin link "$plugin" > /dev/null
	else
		mise exec -- herdr plugin link "$plugin" > /dev/null
	fi
done
