#!/usr/bin/env zsh

export XDG_CONFIG_HOME="$HOME/.config"

# LATER ones have HIGHER priority beause for some dumb reason I'm prepending.
export PATH=/Library/Developer/CommandLineTools/usr/bin:$PATH
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
export PATH=/sbin:$PATH
export PATH=/usr/bin:$PATH
export PATH=/usr/sbin:$PATH
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH
export PATH=$HOME/.bun/bin:$PATH

# If the go directory exists, add its bin directory to the PATH.
if [ -d $HOME/go ]; then
	export PATH=$HOME/go/bin:$PATH
fi

# If the .composer directory exists, add its bin directory to the PATH.
if [ -d $HOME/.composer ]; then
	export PATH=$HOME/.composer/bin:$PATH
	export PATH=$HOME/.composer/vendor/bin:$PATH
fi

export WP_TESTS_DIR=$HOME/Sites/wordpress-development/tests/phpunit

if [ -d $HOME/Applications/terminus/vendor/bin ]; then
	export PATH=$HOME/Applications/terminus/vendor/bin:$PATH
fi

export PATH=/opt/homebrew/sbin:$PATH
export PATH=/opt/homebrew/bin:$PATH
export PATH=$HOME/dotfiles/bin:$PATH

