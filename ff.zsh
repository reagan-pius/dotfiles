# ============================================================================
# ff - fast global file search for macOS (Spotlight + depth-limited fallback)
#
#   ff <term>         numbered list: index, size, full path (user files only)
#   ff . <term>       search the current directory
#   ff -d <dir> <t>   search a specific directory
#   ff -o [N] <t>     open result N (default 1) in its default app
#   ff -r [N] <t>     reveal result N in Finder (alias: ffe)
#   ff -o [N]         no term: open result N of the LAST search
#
# Notes: system paths, ~/Library and dependency trees (node_modules, caches,
# ...) are filtered out. Spotlight never indexes dotfiles - those are found
# by a depth-limited (maxdepth 4) filesystem fallback; for deeper hidden
# files use: ff -d <dir> <term>.
#
# Requirements: macOS + zsh only (mdfind/find/stat/open). No other tools.
# Install: source this file from your .zshrc:
#   [[ -f "$HOME/dotfiles/ff.zsh" ]] && source "$HOME/dotfiles/ff.zsh"
# ============================================================================
ff() {
  emulate -L zsh
  local scope='' mode='' idx='' term p
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|-r) mode="$1"; shift ;;
      -d)
        if (( $# >= 2 )); then scope="${~2}"; shift 2; else
          echo "ff: -d needs a directory argument"; return 1
        fi ;;
      .) scope="$PWD"; shift ;;
      <->) if [[ -n "$mode" ]]; then idx="$1"; shift; else break; fi ;;
      *) break ;;
    esac
  done
  term="$*"
  local state="${TMPDIR:-/tmp}/ff_last_results.txt"
  local -a hits=() keep=() lines=()
  if [[ -z "$term" ]]; then
    # no search term: -o/-r act on the previous search's numbered results
    [[ -n "$mode" ]] || { echo "usage: ff [-d <dir>] <term>  |  ff -o [N] (result N of last search)"; return 1; }
    if [[ -s "$state" ]]; then
      lines=("${(f)$(<"$state")}")
      keep=("${(@)lines[2,-1]}") # line 1 is the meta (term|scope) line
      keep=("${keep[@]:#}")
    fi
    (( ${#keep[@]} )) || { echo "no previous ff search"; return 1; }
  elif [[ "$term" != .* ]]; then
    # same term as the last listing? reuse that exact list so "ff -o N term"
    # opens what the user saw (mdfind's ranking isn't stable between runs)
    if [[ -n "$mode" && -s "$state" ]]; then
      lines=("${(f)$(<"$state")}")
      [[ "${lines[1]}" == "${term}|${scope}" ]] && keep=("${(@)lines[2,-1]}")
      keep=("${keep[@]:#}")
    fi
    if (( ${#keep[@]} == 0 )); then
      if [[ -n "$scope" ]]; then
        hits=("${(f)$(mdfind -onlyin "$scope" -name "$term" 2>/dev/null)}")
      else
        hits=("${(f)$(mdfind -name "$term" 2>/dev/null)}")
      fi
      hits=("${hits[@]:#}") # zsh yields one empty field when mdfind output is empty
      for p in "${hits[@]}"; do
        [[ -f "$p" ]] || continue
        # system roots and dependency trees are noise - drop them
        case "$p" in
          /System/*|/Library/*|/private/*|/usr/*|/opt/*|/Applications/*|"$HOME"/Library/*) continue ;;
        esac
        case "$p" in
          */node_modules/*|*/.git/*|*/.Trash/*|*/.nvm/*|*/.cache/*|*/.venv/*|*/venv/*|*/.npm/*|*/.bun/*|*/go/pkg/*) continue ;;
        esac
        keep+=("$p")
      done
    fi # re-query only when there is no cached list to reuse
  fi

  # Spotlight never indexes dotfiles (and results may be nothing but filtered
  # noise) -> pruned find fallback; when walking all of $HOME, also prune
  # Library and other hidden tool dirs, otherwise they'd take tens of seconds
  if (( ${#keep[@]} == 0 )); then
    local root="${scope:-$HOME}"
    # build prune list as an array - no eval, so any term/paths stay safely quoted
    local -a prune=( \( -name node_modules -o -name .git -o -name .Trash
                     -o -name .nvm -o -name .cache -o -name .venv -o -name venv
                     -o -name .npm -o -name .bun -o -path '*/go/pkg' \) )
    [[ -z "$scope" ]] && prune+=( -o -name Library -o -name .docker )
    keep=("${(f)$(find "$root" -maxdepth 4 "${prune[@]}" -prune -o -type f -iname "*$term*" -print 2>/dev/null)}")
    keep=("${keep[@]:#}")
    (( ${#keep[@]} )) && print -u2 "(no indexed hits - searched the filesystem directly)"
  fi
  (( ${#keep[@]} )) || { echo "no matches for '$term'"; return 1; }
  # remember results so "ff -o N" can reopen them without retyping the term
  [[ -n "$term" ]] && printf '%s\n%s\n' "${term}|${scope}" "${keep[@]}" > "$state" 2>/dev/null

  if [[ -n "$mode" ]]; then
    local n=$(( 10#${idx:-1} )) # force base-10: "08" must not be read as octal
    if (( n >= 1 && n <= ${#keep[@]} )); then
      if [[ "$mode" == -r ]]; then open -R "${keep[n]}"; else open "${keep[n]}"; fi
      return # propagate open's own exit status
    fi
    if [[ -n "$idx" ]]; then
      echo "ff: no result #$n (only ${#keep[@]} result(s))"
    else
      echo "only ${#keep[@]} result(s) for '${term:-last search}'"
    fi
    return 1
  fi

  # display: batched stat for sizes, aligned columns
  local -a shown=("${(@)keep[1,50]}")
  local -A sizes
  local line hb h i=1
  for line in ${(f)"$(stat -f '%z|%N' "${shown[@]}" 2>/dev/null)"}; do
    sizes[${line#*|}]=${line%%|*}
  done
  echo "files (${#keep[@]}):"
  for p in "${shown[@]}"; do
    hb=${sizes[$p]:-}
    if [[ -n "$hb" ]]; then
      if (( hb >= 1073741824 )); then
        h=$(printf '%.1fG' $(( hb / 1073741824.0 )))
      elif (( hb >= 1048576 )); then
        h=$(printf '%.1fM' $(( hb / 1048576.0 )))
      elif (( hb >= 1024 )); then
        h=$(printf '%.1fK' $(( hb / 1024.0 )))
      else
        h="${hb}B"
      fi
    else
      h='?' # file vanished between search and stat
    fi
    printf '  %3d  %7s  %s\n' "$i" "$h" "$p"
    (( i++ ))
  done
  (( ${#keep[@]} > 50 )) && echo "  ... +$(( ${#keep[@]} - 50 )) more"
  return 0
}
alias ffe='ff -r'
