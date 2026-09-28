#!/usr/bin/env bash
# Claude Code custom status line.
# Reads the status-line JSON on stdin and prints one line, e.g.:
#   ◆ Opus 4.8 ⚡high  │  ctx 8% 78k  │  5h 24% ↻45m  ·  wk 41% ↻2d3h
# Fields that aren't present (e.g. rate_limits early in a session) are omitted.

input=$(cat)

# --- parse fields in ONE jq pass (graceful fallbacks for missing values) ---
# This used to be nine separate `jq` invocations, each re-parsing the same JSON.
# Interpreter startup dominated the cost (~135ms total per refresh), and the
# status line re-runs on every refresh of the focused session. One pass now
# emits all nine fields on a single line, delimited by US (\037).
#
# Why \037 and not tab: `read` strips leading/trailing IFS *whitespace*, which
# would silently swallow an empty trailing field (a missing `resets_at` is the
# normal case early in a session). \037 is non-whitespace, so empty fields --
# including the last one -- survive intact.
IFS=$'\037' read -r dir model effort ctx tokens five five_at week week_at <<<"$(
  printf '%s' "$input" | jq -r '[
    .workspace.current_dir                 // "",
    .model.display_name                    // "?",
    .effort.level                          // "",
    .context_window.used_percentage        // "",
    .context_window.total_input_tokens     // "",
    .rate_limits.five_hour.used_percentage // "",
    .rate_limits.five_hour.resets_at       // "",
    .rate_limits.seven_day.used_percentage // "",
    .rate_limits.seven_day.resets_at       // ""
  ] | map(tostring) | join("\u001f")'
)"

# 1M context window is constant for this setup — drop the suffix.
model=${model% (1M context)}

# --- ANSI colors ---
DIM=$'\033[2m'; RESET=$'\033[0m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; BLUE=$'\033[34m'

# Pick a color for a percentage: <70 green, <90 yellow, else red.
pct_color() {
  local v=${1%%.*}   # strip any decimal part for the comparison
  [ -z "$v" ] && { printf '%s' "$RESET"; return; }
  if   [ "$v" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$v" -ge 70 ]; then printf '%s' "$YELLOW"
  else                       printf '%s' "$GREEN"
  fi
}

# Round a possibly-decimal percentage to an integer for display.
round() { printf '%.0f' "$1" 2>/dev/null || printf '%s' "$1"; }

# Compact token count: 78342 -> 78k, 950 -> 950
fmt_tokens() {
  [ -z "$1" ] && return
  if [ "$1" -ge 1000 ]; then printf '%dk' $(( ($1 + 500) / 1000 )); else printf '%d' "$1"; fi
}

# Wall clock, read ONCE. fmt_reset is called twice (5h + weekly window) and each
# call used to spawn its own `date`. Sharing one "now" is also more correct than
# two reads taken microseconds apart.
now=$(date +%s)

# Compact countdown from an epoch-seconds reset time: 2d3h / 4h12m / 45m / now
fmt_reset() {
  [ -z "$1" ] && return
  local d days hrs mins
  d=$(( ${1%%.*} - now ))
  [ "$d" -le 0 ] && { printf 'now'; return; }
  days=$(( d / 86400 )); hrs=$(( (d % 86400) / 3600 )); mins=$(( (d % 3600) / 60 ))
  if   [ "$days" -gt 0 ]; then printf '%dd%dh' "$days" "$hrs"
  elif [ "$hrs"  -gt 0 ]; then printf '%dh%dm' "$hrs" "$mins"
  else                         printf '%dm' "$mins"
  fi
}

sep="${DIM}  │  ${RESET}"

# --- workspace folder + current git branch ---
out=""
if [ -n "$dir" ]; then
  folder=$(basename "$dir")
  out="${BLUE}📁 ${folder}${RESET}"
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && out="${out} ${DIM}⎇ ${RESET}${GREEN}${branch}${RESET}"
  out="${out}${sep}"
fi

# --- model (+ thinking/effort level) ---
out="${out}${CYAN}◆ ${model}${RESET}"
[ -n "$effort" ] && out="${out} ${MAGENTA}⚡${effort}${RESET}"

# --- context: percent + token count ---
if [ -n "$ctx" ]; then
  c=$(pct_color "$ctx")
  out="${out}${sep}${DIM}ctx ${RESET}${c}$(round "$ctx")%${RESET}"
  tk=$(fmt_tokens "$tokens")
  [ -n "$tk" ] && out="${out} ${DIM}${tk}${RESET}"
fi

# --- usage limits: percent + reset countdown ---
if [ -n "$five" ] || [ -n "$week" ]; then
  out="${out}${sep}"
  if [ -n "$five" ]; then
    c=$(pct_color "$five")
    out="${out}${DIM}5h ${RESET}${c}$(round "$five")%${RESET}"
    r=$(fmt_reset "$five_at"); [ -n "$r" ] && out="${out} ${DIM}↻${r}${RESET}"
  fi
  if [ -n "$week" ]; then
    [ -n "$five" ] && out="${out}${DIM}  ·  ${RESET}"
    c=$(pct_color "$week")
    out="${out}${DIM}wk ${RESET}${c}$(round "$week")%${RESET}"
    r=$(fmt_reset "$week_at"); [ -n "$r" ] && out="${out} ${DIM}↻${r}${RESET}"
  fi
fi

# --- PR watch: per-product review counts from ~/.ai-sdlc/pr-watch (gabe-pack pr-watch.sh) ---
#   ⇄ r1 4↻4 · r2 13 · vps 11↻1 · ra 0 · fp 0 │ me 5
#   count: dim 0 · yellow waiting · red ↻N = author pushed / re-requested since my review
#   me: red ✗N changes-requested/ci-failing · green ✓N ready to merge
#   ⇄! red = last scan partial (counts undercount) · whole segment dim + age = watcher stale
pw_dir="$HOME/.ai-sdlc/pr-watch"
pw_tsv="$pw_dir/statusline.tsv"
if [ -r "$pw_tsv" ]; then
  pw_age=$(( now - $(stat -f %m "$pw_tsv" 2>/dev/null || echo "$now") ))
  pw_seg=""; pw_me=""; pw_err=0; pw_any=0
  while IFS=$'\t' read -r kind label count a b; do
    case "$kind" in
      review)
        if [ "$count" = "0" ]; then item="${DIM}${label} 0${RESET}"
        else
          pw_any=1
          item="${DIM}${label}${RESET} ${YELLOW}${count}${RESET}"
          [ "${a:-0}" != "0" ] && item="${item}${RED}↻${a}${RESET}"
        fi
        pw_seg="${pw_seg:+${pw_seg}${DIM} · ${RESET}}${item}" ;;
      mine)
        if [ "$count" = "0" ]; then pw_me="${DIM}${label} 0${RESET}"
        else
          pw_any=1
          pw_me="${DIM}${label}${RESET} ${YELLOW}${count}${RESET}"
          [ "${a:-0}" != "0" ] && pw_me="${pw_me}${RED}✗${a}${RESET}"
          [ "${b:-0}" != "0" ] && pw_me="${pw_me}${GREEN}✓${b}${RESET}"
        fi ;;
      meta) [ "$label" = "errors" ] && pw_err="${count:-0}" ;;
    esac
  done < "$pw_tsv"
  if [ "$pw_age" -gt 7200 ]; then
    # watcher stale: strip colors, dim the lot, show the age
    plain=$(printf '%s' "${pw_seg} │ ${pw_me}" | sed $'s/\033\\[[0-9;]*m//g')
    out="${out}${sep}${DIM}⇄ ${plain} ⏱$(( pw_age / 3600 ))h${RESET}"
  elif [ "$pw_any" = "0" ] && [ "$pw_err" = "0" ]; then
    out="${out}${sep}${GREEN}⇄ all clear${RESET}"
  else
    icon="${CYAN}⇄${RESET}"; [ "$pw_err" != "0" ] && icon="${RED}⇄!${RESET}"
    out="${out}${sep}${icon} ${pw_seg}${pw_me:+${DIM} │ ${RESET}${pw_me}}"
  fi
elif [ -r "$pw_dir/summary.txt" ]; then
  # pre-tsv pr-watch: one-color fallback
  pw_line=$(cat "$pw_dir/summary.txt")
  if [[ "$pw_line" == *[1-9]* || "$pw_line" == *[\?\!]* ]]; then c="$YELLOW"; else c="$GREEN"; fi
  out="${out}${sep}${c}⇄ ${pw_line#PRs }${RESET}"
fi

printf '%s' "$out"
