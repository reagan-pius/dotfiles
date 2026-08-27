# dotfiles

Personal macOS setup, managed with a git repo as the **source of truth** for shell and editor configs.

<!-- > **Note:** this repo is meant to be **private**. It contains personal setup details (paths, aliases, project helpers, email). See [Security](#-security--secrets) below.
-->

## What's inside

| Path | Purpose |
|------|---------|
| `.zshrc` | Zsh config: Oh-My-Zsh + Pure prompt, ~80 aliases, nvm, Docker/Terraform completions, PATHs, project helper (`invite-ash`) |
| `.zprofile` | Login-shell setup: Homebrew shellenv, Antigravity path |
| `.bash_profile` | Bash config: nvm, prompt, aliases |
| `.gitconfig` | Git identity `reagan-pius`, `main` default branch, color + eza aliases |
| `.inputrc` | readline: ignore-case completion, menu-complete |
| `.gitignore` | Global ignore: `node_modules/`, `.DS_Store`, **secrets** (`.zsecrets`) |
| `Brewfile` | Homebrew bundle manifest (formulas, casks, VS Code extensions) — `brew bundle dump` output |
| `config/ghostty/config` | Ghostty terminal settings |
| `config/vscode/settings.json` | VS Code user settings |
| `config/fish/…` | Fish shell `conf.d` + `completions` |
| `config.sh` | Apply: sync repo **→** home (`~` and `~/.config`) |
| `capture-dotfiles.sh` | Capture: sync home **→** repo |
| `reload-dotfiles.sh` | Raycast entry that runs `config.sh` |

## The two directions

- **Apply / deploy (repo → machine)** — `config.sh`
  Installs dotfiles into your home dir and app configs into `~/.config` (and VS Code's Application Support). Used when you get a new machine or want to re-apply everything.
- **Capture (machine → repo)** — `capture-dotfiles.sh`
  Pulls your *live* configs back into the repo so you can commit your machine's current state. The normal routine for updating this repo.

Convenience aliases (defined in `.zshrc`):

```sh
csh   # apply :  repo -> machine        (~/dotfiles/config.sh)
cap   # capture : machine -> repo       (~/dotfiles/capture-dotfiles.sh)
```

## Setup on a new machine

```sh
git clone git@github.com:reagan-pius/dotfiles.git ~/dotfiles
cd ~/dotfiles
./config.sh            # deploy configs to $HOME
brew bundle            # install formulas, casks & VS Code extensions
exec zsh               # or open a new terminal
```

Run `./config.sh` to deploy configs; keys & personal credentials are **not** part of the
repo by design. See [SECRETS-SETUP.md](SECRETS-SETUP.md) for how to restore them on a
new machine.

Requires: **Homebrew**, **Oh-My-Zsh**, and the tools referenced in your aliases (node/pnpm/bun, docker, eza, lazygit, nvim, vercel, stripe, terraform, etc.).

## Daily workflow

```sh
# You edited something locally (e.g. added an alias to ~/.zshrc)
cap                      # capture current machine state into the repo
git -C ~/dotfiles add -A
git -C ~/dotfiles commit -m "add new alias"
git -C ~/dotfiles push
```

```sh
# You want to apply the repo's config to this machine
csh                      # apply repo -> ~
```

<!--## 🔐 Security & secrets

Your `~/.zshrc` historically contained **live API keys**. They have been moved out of tracked files so the repo stays clean.

- Secrets live in **`~/.zsecrets`** (your home dir), which `.zshrc` sources if present:
  ```sh
  [[ -f "$HOME/.zsecrets" ]] && source "$HOME/.zsecrets"
  ```
- `.zsecrets` is **gitignored** and never captured by `capture-dotfiles.sh`.
- `capture-dotfiles.sh --commit` runs a **secret scan** and aborts the commit if any pattern leaks in.
- **Never** put real credentials in `.zshrc` or any tracked file; add new secrets to `~/.zsecrets` instead. Also keep `~/.config/gh/hosts.yml` (GitHub auth) out of the repo.

> Keep this repository **private**. If you accidentally commit a secret — even for a moment — it's potentially public forever; **rotate it**.
-->
## Raycast

`reload-dotfiles.sh` is a Raycast script ("Reload dotfiles") that runs `config.sh` with one click. Edit it in Raycast → Extensions to tweak.

## Maintenance

- Refresh the `Brewfile` to match installed packages:
  ```sh
  cd ~/dotfiles && brew bundle dump --force
  ```
- After any change, run `bash -n <script>.sh` to syntax-check.
