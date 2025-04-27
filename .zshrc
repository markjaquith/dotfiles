# Need to define some things ASAP in order to set up tmux session properly.
export PATH="/opt/homebrew/bin":$PATH
source ~/.zsh/100-aliases.zsh
tmux_ensure_session

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zsh/index.zsh

# Laravel Herd

# Herd injected PHP 7.4 configuration.
export HERD_PHP_74_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/74/"

# Herd injected PHP 8.0 configuration.
export HERD_PHP_80_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/80/"

# Herd injected PHP 8.1 configuration.
export HERD_PHP_81_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/81/"

# Herd injected PHP 8.2 configuration.
export HERD_PHP_82_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/82/"

# Herd injected PHP 8.3 configuration.
export HERD_PHP_83_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/83/"

# Herd injected PHP 8.4 configuration.
export HERD_PHP_84_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/84/"

# Herd injected PHP binary.
export PATH="/Users/mark/Library/Application Support/Herd/bin":$PATH

# bun completions
[ -s "/Users/mark/.bun/_bun.zsh" ] && source "/Users/mark/.bun/_bun.zsh"

# Do an if-false to disable this block.
# Herd will keep adding it, otherwise.
if false; then
# Herd injected NVM configuration
export NVM_DIR="/Users/mark/Library/Application Support/Herd/config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Init work init file
[[ ! -f ~/.work-init.sh ]] || source ~/.work-init.sh


. "$HOME/.local/bin/env"
