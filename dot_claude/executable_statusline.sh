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

# --- PR watch: reviewer-attention counts from ~/.ai-sdlc/pr-watch (pr-watch.sh) ---
pw="$HOME/.ai-sdlc/pr-watch/summary.txt"
if [ -r "$pw" ]; then
  pw_line=$(cat "$pw")
  pw_age=$(( now - $(stat -f %m "$pw" 2>/dev/null || echo "$now") ))
  if [ -n "$pw_line" ]; then
    if   [ "$pw_age" -gt 7200 ]; then c="$DIM"        # watcher hasn't run in 2h
    elif [ "$pw_line" != "PRs r1 0 · r2 0 · vps 0" ]; then c="$YELLOW"
    else c="$GREEN"; fi
    out="${out}${sep}${c}⇄ ${pw_line#PRs }${RESET}"
  fi
fi

printf '%s' "$out"
