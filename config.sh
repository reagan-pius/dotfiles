#!/bin/bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# ----------
# Dotfiles that live directly in the home directory
# ----------
echo "Syncing dotfiles from ${DOTFILES_DIR}..."
for dotfile in .gitconfig .zshrc; do
    cp "$DOTFILES_DIR/$dotfile" "$HOME/$dotfile"
    echo "  ok: $dotfile -> ~/$dotfile"
done

# ----------
# App configs
# ----------

# Ghostty reads its config from ~/.config/ghostty/config
mkdir -p "$HOME/.config/ghostty"
cp "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
echo "  ok: ghostty -> ~/.config/ghostty/config"

# VS Code on macOS stores user settings under Application Support (not ~/.config)
CODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$CODE_USER_DIR"
cp "$DOTFILES_DIR/config/vscode/settings.json" "$CODE_USER_DIR/settings.json"
echo "  ok: vscode -> ~/Library/Application Support/Code/User/settings.json"

echo "Done."
