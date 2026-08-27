#!/bin/bash
# ============================================================================
# capture-dotfiles.sh — reverse sync: machine -> dotfiles repo
#
# Pulls your *live* configs from your home directory into the dotfiles repo,
# so you can commit the current state of your machine. Pairs with config.sh
# (repo -> machine). Uses ~/.zsecrets for secrets, which is deliberately NOT
# captured here to keep the public repo clean.
#
# Usage: sh ~/dotfiles/capture-dotfiles.sh
#        (optionally: sh ~/dotfiles/capture-dotfiles.sh --commit)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

echo "Capturing current machine state into ${DOTFILES_DIR}..."

# ----------
# Home-directory dotfiles
# ----------
for dotfile in .zshrc .zprofile .bash_profile .inputrc .gitconfig .gitignore; do
    src="$HOME/$dotfile"
    if [[ -f "$src" ]]; then
        cp "$src" "$DOTFILES_DIR/$dotfile"
        echo "  captured: ~/$dotfile"
    else
        echo "  skip (not present): ~/$dotfile"
    fi
done

# ----------
# Fish config
# ----------
mkdir -p "$DOTFILES_DIR/config/fish/conf.d" "$DOTFILES_DIR/config/fish/completions"
for f in "$HOME"/.config/fish/conf.d/*.fish; do
    [[ -f "$f" ]] && cp "$f" "$DOTFILES_DIR/config/fish/conf.d/" && echo "  captured: fish conf.d/$(basename "$f")"
done
for f in "$HOME"/.config/fish/completions/*.fish; do
    [[ -f "$f" ]] && cp "$f" "$DOTFILES_DIR/config/fish/completions/" && echo "  captured: fish completions/$(basename "$f")"
done

# ----------
# Ghostty (optional, only if present locally)
# ----------
if [[ -f "$HOME/.config/ghostty/config" ]]; then
    mkdir -p "$DOTFILES_DIR/config/ghostty"
    cp "$HOME/.config/ghostty/config" "$DOTFILES_DIR/config/ghostty/config"
    echo "  captured: ghostty"
else
    echo "  skip: ghostty (no ~/.config/ghostty/config)"
fi

echo
echo "Done. Review with 'git -C $DOTFILES_DIR status', then commit."

# ----------
# Optional one-shot: commit + push
# ----------
if [[ "${1:-}" == "--commit" ]]; then
    cd "$DOTFILES_DIR"
    git add -A
    # Safety: refuse to commit if a secret slipped in
    if grep -rIlnE '(lin_api_[A-Za-z0-9]{8,}|sk-[A-Za-z0-9]{15,}|re_[A-Za-z0-9]{20,})' . --exclude-dir=.git --exclude=.zsecrets; then
        echo "ABORTED: possible secret found in repo. Check the listed files."
        exit 1
    fi
    git commit -m "Sync live machine config into dotfiles"
fi