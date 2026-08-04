# Set ZSH_PERF=1 before starting a shell to log startup, command, and directory
# change timings. See ~/.zsh/perf.zsh for options and the log format.
if [[ -n "${ZSH_PERF:-}" ]]; then
	source ~/.zsh/perf.zsh
fi

# Herd and Bun append tool-managed code below, so leave their blocks in this
# file instead of moving them into ~/.zsh/.
if (( $+functions[_zsh_perf_source] )); then
	_zsh_perf_source early-paths ~/.zsh/010-paths.zsh
	_zsh_perf_source early-tmux ~/.zsh/015-tmux.zsh
else
	source ~/.zsh/010-paths.zsh
	source ~/.zsh/015-tmux.zsh
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	if (( $+functions[_zsh_perf_source] )); then
		_zsh_perf_source p10k-instant-prompt \
			"${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
	else
		source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi
fi

if (( $+functions[_zsh_perf_source] )); then
	_zsh_perf_source zsh-index ~/.zsh/index.zsh
else
	source ~/.zsh/index.zsh
fi

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

# Herd injected PHP 8.5 configuration.
export HERD_PHP_85_INI_SCAN_DIR="/Users/mark/Library/Application Support/Herd/config/php/85/"

# Herd injected PHP binary.
export PATH="/Users/mark/Library/Application Support/Herd/bin":$PATH

# bun completions
if [ -s "/Users/mark/.bun/_bun.zsh" ]; then
	if (( $+functions[_zsh_perf_source] )); then
		_zsh_perf_source bun-generated-completions "/Users/mark/.bun/_bun.zsh"
	else
		source "/Users/mark/.bun/_bun.zsh"
	fi
fi

# Do an if-false to disable this block.
# Herd will keep adding it, otherwise.
if false; then
# Herd injected NVM configuration
export NVM_DIR="/Users/mark/Library/Application Support/Herd/config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -f ~/.p10k.zsh ]]; then
	if (( $+functions[_zsh_perf_source] )); then
		_zsh_perf_source p10k-config ~/.p10k.zsh
	else
		source ~/.p10k.zsh
	fi
fi

# Init local dotfiles
if [[ -f ~/.local-dotfiles/local-init.zsh ]]; then
	if (( $+functions[_zsh_perf_source] )); then
		_zsh_perf_source local-init ~/.local-dotfiles/local-init.zsh
	else
		source ~/.local-dotfiles/local-init.zsh
	fi
fi

if (( $+functions[_zsh_perf_source] )); then
	_zsh_perf_source local-bin-env "$HOME/.local/bin/env"
else
	. "$HOME/.local/bin/env"
fi

(( $+functions[_zsh_perf_begin] )) && _zsh_perf_begin worktrunk-init
if command -v wt >/dev/null 2>&1; then
	eval "$(command wt config shell init zsh)"
fi
(( $+functions[_zsh_perf_end] )) && _zsh_perf_end worktrunk-init

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

(( $+functions[_zsh_perf_install_hooks] )) && _zsh_perf_install_hooks
