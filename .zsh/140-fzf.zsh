zinit light Aloxaf/fzf-tab
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza $realpath'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group '<' '>'

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# Fzf config.
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# Fzf theme.
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"


# DISABLED because it causes issues with Spring
# export FZF_DEFAULT_OPTS='
# --height 80%
# --pointer=
# --marker=
# --color=fg:#cad3f5,bg:#24273a,hl:#ed8796
# --color=fg+:#cad3f5,bg+:#5b6078,hl+:#ed8796
# --color=info:#8aadf4,prompt:#f4dbd6,pointer:#f5a97f
# --color=marker:#a6da95,spinner:#f5a97f,header:#c6a0f6
# '

export FZF_DEFAULT_OPTS='
--height 80%
--pointer=">"
--marker="x"
--color=fg:#cad3f5,bg:#24273a,hl:#ed8796
--color=fg+:#cad3f5,bg+:#5b6078,hl+:#ed8796
--color=info:#8aadf4,prompt:#f4dbd6,pointer:#f5a97f
--color=marker:#a6da95,spinner:#f5a97f,header:#c6a0f6
'

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
