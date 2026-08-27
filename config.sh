#!/bin/bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# ----------
# Dotfiles that live directly in the home directory
# ----------
echo "Syncing dotfiles from ${DOTFILES_DIR}..."
HOME_DOTFILES=(.gitconfig .zshrc .zprofile .bash_profile .inputrc)
for dotfile in "${HOME_DOTFILES[@]}"; do
    if [[ -f "$DOTFILES_DIR/$dotfile" ]]; then
        cp "$DOTFILES_DIR/$dotfile" "$HOME/$dotfile"
        echo "  ok: $dotfile -> ~/$dotfile"
    fi
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

# ----------
# Fish config
# ----------
if [[ -d "$DOTFILES_DIR/config/fish" ]]; then
    mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/fish/completions"
    for f in "$DOTFILES_DIR"/config/fish/conf.d/*.fish; do
        [[ -f "$f" ]] && cp "$f" "$HOME/.config/fish/conf.d/" && echo "  ok: fish conf.d/$(basename "$f")"
    done
    for f in "$DOTFILES_DIR"/config/fish/completions/*.fish; do
        [[ -f "$f" ]] && cp "$f" "$HOME/.config/fish/completions/" && echo "  ok: fish completions/$(basename "$f")"
    done
fi

echo "Done."
