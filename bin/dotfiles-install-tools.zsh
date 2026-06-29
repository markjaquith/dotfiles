#!/usr/bin/env zsh
# Manual tool installs

# Configure tmux plugin and resurrect directories
mkdir -p "$HOME/.local/bin/tmux/plugins"
mkdir -p "$HOME/.local/state/tmux/resurrect"

# Install tmux tpm
if [[ ! -d "$HOME/.local/bin/tmux/plugins/tpm" ]]; then
	git clone https://github.com/tmux-plugins/tpm "$HOME/.local/bin/tmux/plugins/tpm"
fi

# Install tmux plugins declared in tmux.conf
if command -v tmux &>/dev/null; then
	tmux start-server
	tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.local/bin/tmux/plugins"
	"$HOME/.local/bin/tmux/plugins/tpm/bin/install_plugins"
fi

# phpactor
if ! command -v phpactor &>/dev/null; then
  echo "Prompting for password to install phpactor to /usr/local/bin..."
  sudo curl -sLo /usr/local/bin/phpactor https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar
  sudo chmod +x /usr/local/bin/phpactor
fi

# Rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

if command -v rustup &>/dev/null; then
  if ! command -v cargo &>/dev/null; then
    rustup toolchain install stable
  fi
  rustup update stable
  rustup default stable > /dev/null 2>&1
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
fi

if command -v cargo &>/dev/null; then
  # cmdy
  if ! command -v cmdy &>/dev/null; then
    cargo install cmdy
  fi

  # wrappy
  if ! command -v wrappy &>/dev/null; then
    cargo install wrappy
  fi

  # worktrunk
  cargo install --locked worktrunk
else
  echo "Warning: cargo not found, skipping Rust package installs"
fi

# framecap
if ! command -v framecap &>/dev/null; then
	"${SCRIPT_DIR}/dotfiles-install-framecap.zsh"
fi

# Local env
mkdir -p ~/.local/bin
touch ~/.local/bin/env
