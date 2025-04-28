#!/usr/bin/env zsh
# Set up git hooks

current_hooks_path=$(git -C "$DOTFILES_DIR" config --get core.hooksPath 2>/dev/null)
get_config_exit_code=$?

if [ $get_config_exit_code -ne 0 ] || [ "$current_hooks_path" != "$VERSION_CONTROLLED_HOOKS_DIR" ]; then
    echo "Setting core.hooksPath for $DOTFILES_DIR..."
    if git -C "$DOTFILES_DIR" config core.hooksPath "$VERSION_CONTROLLED_HOOKS_DIR"; then
        echo "Git hooks for $DOTFILES_DIR are now managed from the '$VERSION_CONTROLLED_HOOKS_DIR' directory."
    else
        echo "Error: Failed to set core.hooksPath for $DOTFILES_DIR." >&2
        return 1
    fi
fi

HOOK_FILE_PATH="$DOTFILES_DIR/$VERSION_CONTROLLED_HOOKS_DIR/pre-push"
if [ -f "$HOOK_FILE_PATH" ]; then
    if ! chmod +x "$HOOK_FILE_PATH"; then
        echo "Warning: Could not make hook executable: $HOOK_FILE_PATH" >&2
    fi
fi