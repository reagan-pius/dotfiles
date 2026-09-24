# 🔑 Secrets Setup (`~/.zsecrets`)

> ⚠️ **Never put real values in this file (or any tracked file).** This document uses
> placeholders only. The dotfiles repo is public-safe by design; real credentials
> belong exclusively in `~/.zsecrets`, which is gitignored.

## What's managed here

Your shell loads these environment variables, sourced from `~/.zsecrets`:

| Variable | Provider | Where to re-issue |
|----------|----------|-------------------|
| `LINEAR_API_KEY` | Linear | Linear → Settings → Security → **API keys** |
| `ANTHROPIC_AUTH_TOKEN` | DeepSeek (Anthropic-compatible endpoint) | DeepSeek Console → **API Keys** |
| `ANTHROPIC_BASE_URL` | DeepSeek | `https://api.deepseek.com/anthropic` (static) |
| `RESEND_API_KEY` | Resend | resend.com → **API Keys** |

The file looks like this (placeholders shown — replace with your real values):

```sh
# ~/.zsecrets  —  chmod 600
export LINEAR_API_KEY="<YOUR_LINEAR_API_KEY>"
export ANTHROPIC_AUTH_TOKEN="<YOUR_DEEPSEEK_KEY>"
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export RESEND_API_KEY="<YOUR_RESEND_API_KEY>"
```

`.zshrc` sources it only if present, so a machine without this file just works (those
vars are simply unset):

```sh
[[ -f "$HOME/.zsecrets" ]] && source "$HOME/.zsecrets"
```

## Managing secrets with the `secret` helpers

`.zshrc` (tracked, so the helpers travel with the repo) defines three functions that own
`~/.zsecrets` for you. They write atomically, `chmod 600` the file, verify the line landed
exactly once, and scrub the value from `~/.zsh_history` (on disk **and** in the live
session) so a key never lingers in plaintext:

```sh
secret NAME 'value'   # set: persist to ~/.zsecrets + export in this session
secret NAME           # check: persisted? exported right now?
secret -l             # list persisted names (values are never printed)
rotate NAME 'new'     # set new value + scrub the old one from history
unsecret NAME         # remove + unset + scrub   (-y to skip the prompt)
```

They only ever reference the *path* `~/.zsecrets` — no values live in the repo. `rotate`
and `unsecret` also remind you to **revoke** the old credential at the provider dashboard.

## Restoring on a new machine (3 steps)

1. **Deploy the repo** (see README → "Setup on a new machine"):
   ```sh
   git clone git@github.com:reagan-pius/dotfiles.git ~/dotfiles
   cd ~/dotfiles && ./config.sh && brew bundle
   ```
2. **Get your keys onto the new machine** — pick one:
   - **Password manager (recommended):** store the contents of `~/.zsecrets`
     as a note in 1Password/Bitwarden/iCloud Keychain now. On the new machine,
     recreate the file from that note.
   - **SCP/AirDrop from this machine:**
     ```sh
     # from the NEW machine, on the same network
     scp rgnpx@<OLD_MACHINE_IP>:~/.zsecrets ~/.zsecrets
     chmod 600 ~/.zsecrets
     ```
   - **Re-issue from each provider dashboard** (table above), then write a fresh
     `~/.zsecrets`.
3. **Activate:**
   ```sh
   chmod 600 ~/.zsecrets
   exec zsh        # reload the shell
   ```
   Verify with: `echo $LINEAR_API_KEY` (prints your key — expected), and run the tool
   that uses it once.

## Rules

- **Never** add real key values to any file tracked by git.
- `~/.zsecrets` must stay **untracked** — it's in `.gitignore` and is skipped by
  `capture-dotfiles.sh`.
- If you ever *suspect* a key leaked (public commit, shared machine, lost laptop):
  **rotate it** at the provider even if it wasn't committed — rotation is the only
  way to evict an exposed credential.
- Keep `~/.config/gh/hosts.yml` (GitHub auth) out of the repo too.
- `config/vscode/mcp.json` **is** tracked and this repo is **public**: keep MCP servers
  pointed at URLs or `npx` commands and read tokens from the environment
  (`"${env:MY_TOKEN}"`) — never paste a key into it.
- Cursor's `~/.cursor/cli-config.json` holds auth state (`authInfo`) and is deliberately
  **not** tracked, same as `hosts.yml`.