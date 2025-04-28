#!/usr/bin/env zsh
# Manual tool installs

# Configure tmux plugin directory
mkdir -p ~/.local/bin/tmux/plugins

# Install tmux tpm
if [ ! -d ~/.local/bin/tmux/plugins/tpm ]; then
	git clone https://github.com/tmux-plugins/tpm ~/.local/bin/tmux/plugins/tpm
fi

# phpactor
if ! command -v phpactor &>/dev/null; then
  echo "Prompting for password to install phpactor to /usr/local/bin..."
  sudo curl -sLo /usr/local/bin/phpactor https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar
  sudo chmod +x /usr/local/bin/phpactor
fi

# Rust
if ! command -v cargo &>/dev/null; then
  echo "1" | rustup-init
  rustup install stable
  rustup default stable > /dev/null 2>&1
fi

# Ensure that the local dotfiles pet dir exists
mkdir -p "$LOCAL_DOTFILES_DIR/.config/pet"

# Local env
mkdir -p ~/.local/bin
touch ~/.local/bin/env
