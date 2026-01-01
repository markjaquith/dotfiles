# Set the editor to Neovim, unless it doesn't exist, in which case use vim.
export EDITOR=nvim
if ! command -v nvim >/dev/null 2>&1; then
  export EDITOR=vim
fi
