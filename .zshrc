export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

autoload -U promptinit; promptinit
prompt pure

CASE_SENSITIVE="true"
ENABLE_CORRECTION="true"

plugins=(git docker)

source $ZSH/oh-my-zsh.sh

export EDITOR='code -w'
export TERM=xterm-256color

# ------- 
# Aliases 
# -------
#alias l="ls" # List files in current directory
#alias ll="ls -al" # List all files in current directory in long list format
alias o="open ." # Open the current directory in Finder
alias ghost="gs" # replace ghostscript command so git status works properly
alias lint="npx next lint"
alias ng="ngrok http --url=caccamedia.ngrok.dev"
alias c="clear"
alias lg="lazygit" 
alias sz="source ~/.zshrc"
alias csh="~/dotfiles/config.sh"
alias cap="~/dotfiles/capture-dotfiles.sh"

# ff - fast global file search (Spotlight, with filesystem fallback)
# lives in ~/dotfiles/ff.zsh so it is shareable independently
[[ -f "$HOME/dotfiles/ff.zsh" ]] && source "$HOME/dotfiles/ff.zsh"

# -------
# pnpm Aliases
# -------
alias p="pnpm"
alias pi="pnpm install"
alias pa="pnpm add"
alias pd="pnpm dev"
alias pb="pnpm build"
alias pr="pnpm run"
alias psd="pnpm start:dev"

# ----------------------
# bun Aliases
# ----------------------
alias b="bun"
alias bi="bun install"
alias bd="bun dev"

# ----------------------
# Git Aliases
# ----------------------
alias gi='git init'
alias gro='git remote add origin'
alias ga='git add'
alias gaa='git add .'
alias gcm='git commit -m'
alias gpsh='git push'
alias gpsho='git push -u origin'
alias gss='git status -s'
alias gs='echo ""; echo "*********************************************"; echo -e "   DO NOT FORGET TO PULL BEFORE COMMITTING"; echo "*********************************************"; echo ""; git status'

# ----------------------
# Docker Aliases
# ----------------------
alias d='docker'
alias dps='docker ps'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dcud='docker compose up -d'
alias ds='docker sandbox'
alias dsls='docker sandbox ls'
alias dcs='docker sandbox run --template ghcr.io/byga-net/custom-docker-sandbox:latest claude'

# ----------------------
# Rails Aliases
# ----------------------
alias rc='rails c'
alias rdm='rake db:migrate'
alias rdb='rake db:rollback'
alias bundlei='bundle install' # 'bi' is already used by bun install
alias rrg='rake routes | grep'

# ----------------------
# Vercel Aliases
# ----------------------
alias v='vercel'
alias vb='vercel build'
alias vd='vercel deploy'
alias vls='vercel ls'
alias vpr='vercel pull --environment=production'
alias vps='vercel pull --environment=preview'
alias vpsh='vercel push --environment=preview'
alias vprh='vercel push --environment=production'

# ----------------------
# Neovim Aliases
# ----------------------
alias vim='nvim'
alias nv='nvim'

# ----------------------
# Eza Aliases
# ----------------------
alias ls='eza --git --group-directories-first --icons'
alias l='eza --git --group-directories-first --icons'
alias ll='eza --git --group-directories-first --icons -alF'
alias la='eza --git --group-directories-first --icons -a'

# ----------------------
# Stripe Aliases
# ----------------------
alias sl='stripe login'
alias slf='stripe listen --forward-to'

# ----------------------
# Flush DNS
# ----------------------
alias flushdns="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo 'DNS cache flushed'"

# ----------------------
# Node Version Manager (nvm)
# ----------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="$HOME/.nvm/versions/node/v25.6.1/bin:$PATH"

# ----------------------
# Terraform completions
# ----------------------
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

# ----------------------
# Docker CLI completions
# ----------------------
fpath=(/Users/rgnpx/.docker/completions $fpath)
autoload -Uz compinit
compinit

# ----------------------
# PATH additions
# ----------------------
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# ----------------------
# Local secrets (gitignored; see ~/.zsecrets)
# ----------------------
[[ -f "$HOME/.zsecrets" ]] && source "$HOME/.zsecrets"

# ======================================================================
# Secret management: secret / rotate / unsecret
# Deterministic helpers for ~/.zsecrets (gitignored, chmod 600).
# All edits are atomic + verified; all failures are loud (non-zero exit).
# ======================================================================

# _sec_validate NAME -> 0 if NAME is a valid shell variable name
_sec_validate() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

# _sec_scrub_history NAME OLDVALUE [TAG]
# Removes every history line containing both NAME and OLDVALUE.
# Scrubs the on-disk file AND reloads it into this session's in-memory
# history (fc -R), otherwise the running shell would rewrite the
# plaintext back to disk when it exits.
_sec_scrub_history() {
  local name="$1" old="$2" tag="${3:-scrubbed}" f="$HOME/.zsh_history"
  [[ -n "$old" ]] || return 0
  [[ -f "$f" ]] || return 0

  local tmp err
  tmp=$(mktemp) || { print -u2 "❌ mktemp failed"; return 1; }
  err=$(_SEC_NAME="$name" _SEC_OLD="$old" _SEC_TAG="$tag" perl -e '
    open(my $in, "<", $ENV{"SEC_FILE"}) or die "open: $!";
    my @lines = <$in>; close $in;
    foreach my $l (@lines) {
      if (index($l, $ENV{"_SEC_NAME"}) >= 0 && index($l, $ENV{"_SEC_OLD"}) >= 0) {
        $l = ": <REDACTED by " . $ENV{"_SEC_TAG"} . ">\\n";
      }
    }
    open(my $out, ">", $ENV{"SEC_OUT"}) or die "write: $!";
    print $out @lines; close $out;
  ' SEC_FILE="$f" SEC_OUT="$tmp" 2>&1) || { rm -f "$tmp"; print -u2 "❌ history scrub failed: $err"; return 1; }
  mv "$tmp" "$f" || { rm -f "$tmp"; print -u2 "❌ history scrub failed (replace)"; return 1; }
  chmod 600 "$f"

  # reload scrubbed file into this shell's in-memory history
  fc -R "$f" 2>/dev/null
  print -u2 "🧹 history scrubbed (file + this session)"
  return 0
}

# secret NAME [VALUE]
#   secret NAME 'value' -> validate, write to ~/.zsecrets, export now
#   secret NAME         -> check persisted/session state
#   secret -l           -> list persisted names (values never shown)
secret() {
  local f="$HOME/.zsecrets"

  if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    [[ -f "$f" ]] || { print -u2 "❌ $f does not exist"; return 1; }
    grep -oE '^export [A-Za-z_][A-Za-z0-9_]*=' "$f" | sed 's/^export //; s/=$//'
    return 0
  fi

  if [[ -z "$1" ]]; then
    echo "Usage: secret NAME ['value'] | secret -l"
    return 1
  fi
  if ! _sec_validate "$1"; then
    print -u2 "❌ invalid name '$1' (must match [A-Za-z_][A-Za-z0-9_]*)"
    return 1
  fi

  # Check mode
  if [[ -z "$2" ]]; then
    if [[ -f "$f" ]] && grep -q "^export $1=" "$f"; then
      echo "✅ $1 persisted in $f"
      [[ -n "${(P)1}" ]] && echo "   and set in this session" \
        || echo "   but NOT set in this session (run: source $f)"
    else
      echo "❌ $1 not in $f"
      return 1
    fi
    return 0
  fi

  # Set mode — reject values that would corrupt the quoted export line
  local _nl=$'\n'
  if [[ "$2" == *'"'* || "$2" == *"$_nl"* ]]; then
    print -u2 "❌ value contains a double quote or newline — refusing to write"
    return 1
  fi

  # atomic rewrite: filter out old line, append new one, then verify
  local tmp
  tmp=$(mktemp) || { print -u2 "❌ mktemp failed"; return 1; }
  grep -v "^export $1=" "$f" > "$tmp" 2>/dev/null || true
  printf 'export %s="%s"\n' "$1" "$2" >> "$tmp" || { rm -f "$tmp"; print -u2 "❌ write failed"; return 1; }
  mv "$tmp" "$f" || { rm -f "$tmp"; print -u2 "❌ failed to replace $f"; return 1; }
  chmod 600 "$f" || { print -u2 "❌ chmod 600 $f failed"; return 1; }

  # verify the line landed exactly once
  if [[ $(grep -c "^export $1=" "$f") -ne 1 ]]; then
    print -u2 "❌ verification failed: $1 not written exactly once"
    return 1
  fi

  export "$1=$2"
  echo "✅ $1 set in this session and persisted to $f"
  return 0
}

# rotate NAME 'new-value'
# Updates a secret and scrubs the old value from shell history
# (file + in-memory). Reminds you to revoke at the provider.
rotate() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: rotate NAME 'new-value'"
    return 1
  fi
  if ! _sec_validate "$1"; then
    print -u2 "❌ invalid name '$1'"
    return 1
  fi

  local name="$1" new="$2" old=""
  old="${(P)name}"   # prefer the live session value
  if [[ -z "$old" && -f "$HOME/.zsecrets" ]]; then
    old=$(sed -n "s/^export $name=\"\\(.*\)\"\$/\1/p" "$HOME/.zsecrets")
  fi

  secret "$name" "$new" || return 1

  if [[ -n "$old" ]]; then
    _sec_scrub_history "$name" "$old" "rotate" || return 1
  fi

  echo "⚠️  Remember: rotate also means REVOKE the old key at the provider dashboard if it was ever exposed."
  return 0
}

# unsecret NAME [-y]
# Removes a secret from ~/.zsecrets and the session, scrubs history.
unsecret() {
  local name="$1" flag="$2"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    echo "Usage: unsecret NAME [-y]"
    return 1
  fi
  if ! _sec_validate "$name"; then
    print -u2 "❌ invalid name '$name'"
    return 1
  fi

  local f="$HOME/.zsecrets"
  if [[ ! -f "$f" ]] || ! grep -q "^export $name=" "$f"; then
    print -u2 "❌ $name not found in $f"
    return 1
  fi

  if [[ "$flag" != "-y" ]]; then
    printf "Remove %s from %s? [y/N] " "$name" "$f"
    local reply
    read -r reply
    [[ "$reply" == "y" || "$reply" == "Y" ]] || { echo "Aborted."; return 1; }
  fi

  local old
  old=$(sed -n "s/^export $name=\"\\(.*\)\"\$/\1/p" "$f")

  local tmp
  tmp=$(mktemp) || { print -u2 "❌ mktemp failed"; return 1; }
  grep -v "^export $name=" "$f" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$f" || { rm -f "$tmp"; print -u2 "❌ failed to replace $f"; return 1; }
  chmod 600 "$f" || { print -u2 "❌ chmod 600 $f failed"; return 1; }

  # verify: zero occurrences remain
  if [[ $(grep -c "^export $name=" "$f") -ne 0 ]]; then
    print -u2 "❌ verification failed: $name still present after removal"
    return 1
  fi

  unset "$name" 2>/dev/null

  if [[ -n "$old" ]]; then
    _sec_scrub_history "$name" "$old" "unsecret" || return 1
  fi

  echo "✅ $name removed from $f and unset in this session"
  echo "⚠️  If the key is still active at the provider, revoke it there too."
  return 0
}


# List Ashinaga pending invite signup links
invite-ash() {
  docker exec ashinaga-postgres-1 psql -U postgres -d postgres -tA -c "select email || ' -> http://localhost:' || case when user_type='staff' then '4001' else '4002' end || '/signup?token=' || token from invitations where status='pending'"
}
