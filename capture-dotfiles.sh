#!/bin/bash
# ============================================================================
# capture-dotfiles.sh — reverse sync: machine -> dotfiles repo
#
# Pulls your *live* configs from your home directory into the dotfiles repo,
# so you can commit the current state of your machine. Pairs with config.sh
# (repo -> machine). Uses ~/.zsecrets for secrets, which is deliberately NOT
# captured here to keep the public repo clean.
#
# Usage: sh ~/dotfiles/capture-dotfiles.sh           # capture into the repo
#        sh ~/dotfiles/capture-dotfiles.sh --check   # run the secret gates only
#        sh ~/dotfiles/capture-dotfiles.sh --commit  # capture, gate, commit
#
# --check/--commit refuse to proceed when a secret gate fails (this repo is
# public). See "Secret gates" near the bottom of this file.
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

echo "Capturing current machine state into ${DOTFILES_DIR}..."

# ----------
# Home-directory dotfiles
# ----------
for dotfile in .zshrc .zprofile .bash_profile .profile .inputrc .gitconfig .gitignore; do
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

# ----------
# VS Code user settings (macOS stores these under Application Support)
# ----------
CODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if [[ -f "$CODE_USER_DIR/settings.json" ]]; then
    mkdir -p "$DOTFILES_DIR/config/vscode"
    cp "$CODE_USER_DIR/settings.json" "$DOTFILES_DIR/config/vscode/settings.json"
    echo "  captured: vscode settings"
    if [[ -f "$CODE_USER_DIR/mcp.json" ]]; then
        cp "$CODE_USER_DIR/mcp.json" "$DOTFILES_DIR/config/vscode/mcp.json"
        echo "  captured: vscode mcp.json"
    else
        echo "  skip: vscode mcp.json (not present)"
    fi
else
    echo "  skip: vscode (no ~/Library/Application Support/Code/User/settings.json)"
fi

# ----------
# Cursor user settings (same layout as VS Code, different app dir)
# ----------
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
if [[ -f "$CURSOR_USER_DIR/settings.json" ]]; then
    mkdir -p "$DOTFILES_DIR/config/cursor"
    cp "$CURSOR_USER_DIR/settings.json" "$DOTFILES_DIR/config/cursor/settings.json"
    echo "  captured: cursor settings"
else
    echo "  skip: cursor (no ~/Library/Application Support/Cursor/User/settings.json)"
fi

echo
echo "Done. Review with 'git -C $DOTFILES_DIR status', then commit."

# ============================================================================
# Secret gates — run before anything is committed
# ============================================================================
# This repo is public, so a single leaked key is public forever. Three layers:
#   1. known credential shapes anywhere in the repo
#   2. mcp.json — values under "env"/"headers" must be ${env:...}/${input:...}
#      placeholders; a literal there is refused (keep it in ~/.zsecrets)
#   3. mcp.json — raw-looking tokens anywhere, so a bare hex/base64 secret under
#      an innocent key name (FOO) is still caught, plus inline bearer/query creds
SECRET_SHAPES='(lin_api_[A-Za-z0-9]{8,}|sk-[A-Za-z0-9]{15,}|re_[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,})'
OPAQUE_TOKENS='("[0-9a-fA-F]{32,}"|"[A-Za-z0-9+=_-]{40,}"|[Bb]earer[[:space:]]+[A-Za-z0-9._-]{16,}|[?&](access_)?(token|api_?key)=[A-Za-z0-9._-]{8,})'

# mcp_placeholder_gate FILE -> prints offending lines, exits non-zero if any
# value inside an "env"/"headers" object is a non-empty literal. The JSON is
# walked as text, tracking brace depth to find those objects (balanced braces
# inside strings, e.g. ${env:X}, cancel out; full-line // comments are skipped).
mcp_placeholder_gate() {
    awk '
        function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }

        function check(line,   rest, pair, klen, v, inner) {
            rest = line
            while (match(rest, /"[^"]*"[ \t]*:[ \t]*"[^"]*"/)) {
                pair = substr(rest, RSTART, RLENGTH)
                rest = substr(rest, RSTART + RLENGTH)

                klen = 0
                if (match(pair, /^"[^"]*"/)) klen = RLENGTH
                v = trim(substr(pair, klen + 1))
                v = trim(substr(v, 2))
                if (v !~ /^".*"$/) continue
                inner = substr(v, 2, length(v) - 2)

                if (inner == "") continue
                if (inner ~ /^\$\{(env|input):[^}]*\}$/) continue
                printf "   %s:%d: literal where a placeholder is required -> \"%s\"\n", FILENAME, FNR, inner
                bad = 1
            }
        }

        {
            line = $0
            if (line ~ /^[ \t]*\/\//) next
            touched = (inblock ? 1 : 0)
            if (line ~ /"(env|headers)"[ \t]*:[ \t]*\{/) pending = 1
            for (i = 1; i <= length(line); i++) {
                c = substr(line, i, 1)
                if (c == "{") {
                    depth++
                    if (pending) { pending = 0; inblock = 1; blockdepth = depth; touched = 1 }
                } else if (c == "}") {
                    depth--
                    if (inblock && depth < blockdepth) inblock = 0
                }
            }
            if (touched) check(line)
        }

        END { if (bad) exit 1 }
    ' "$1"
}

# run_secret_gates -> 0 when clean, 1 when something must be fixed
run_secret_gates() {
    local failed=0 hits mcp

    if hits=$(grep -rIlnE "$SECRET_SHAPES" "$DOTFILES_DIR" --exclude-dir=.git --exclude=.zsecrets); then
        echo "❌ known credential shape found in:"
        printf '   %s\n' $hits
        failed=1
    fi

    while IFS= read -r mcp; do
        [[ -n "$mcp" ]] || continue
        if ! mcp_placeholder_gate "$DOTFILES_DIR/$mcp"; then
            echo "❌ $mcp: literal where a placeholder is required"
            echo "   fix: use \"\${env:NAME}\" here and keep the value in ~/.zsecrets"
            failed=1
        fi
        if hits=$(grep -InE "$OPAQUE_TOKENS" "$DOTFILES_DIR/$mcp"); then
            echo "❌ $mcp: looks like a raw token:"
            printf '   %s\n' "$hits"
            failed=1
        fi
    done < <(git -C "$DOTFILES_DIR" ls-files '*mcp.json')

    return $failed
}

# ----------
# Optional one-shot: gate, then commit (--commit) or gate only (--check)
# ----------
case "${1:-}" in
    --check|--commit)
        cd "$DOTFILES_DIR"
        if [[ "${1:-}" == "--commit" ]]; then
            git add -A
        fi
        echo
        echo "Running secret gates..."
        if ! run_secret_gates; then
            echo
            echo "ABORTED: a secret gate failed — nothing was committed."
            echo "Fix the value (or move it into ~/.zsecrets) and re-run."
            exit 1
        fi
        echo "✅ all secret gates passed."
        if [[ "${1:-}" == "--commit" ]]; then
            if git diff --cached --quiet; then
                echo "Nothing to commit — the repo already matches this machine."
            else
                git commit -m "Sync live machine config into dotfiles"
            fi
        fi
        ;;
esac