# Set the editor to Neovim, unless it doesn't exist, in which case use vim.
export EDITOR=nvim
if ! command -v nvim >/dev/null 2>&1; then
  export EDITOR=vim
fi

# Reduce delay when pressing Esc in vim mode
if [[ -n $SSH_TTY || -n $SSH_CONNECTION || -n $MOSH_CONNECTION ]]; then
  export KEYTIMEOUT=5    # 50 ms: protects Meta sequences over flaky SSH links
else
  export KEYTIMEOUT=1    # 10 ms: feels instant
fi

