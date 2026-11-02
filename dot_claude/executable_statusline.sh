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

# --- usage limits: moved to the metamux sidebar's `dashboard` section (2026-11-02).
#   Feed: ~/.metamux/feeds/claude-limits.json (plugin `claude-limits`), one chip per
#   window: `5h 24%↻45m  wk 41%↻2d3h`, percent and countdown on separate
#   red-green gradients (levels below). Tier mirrors pct_color: <70 ok, <90 warn,
#   else alert. Written only when the chips change (or every 5 min, so `ts` stays
#   fresh); the write is temp+rename in the feeds dir, which is what wakes the
#   sidebar. Previous segment: statusline.sh.bak-20261102-limits
pct_tier() {
  local v=${1%%.*}
  if   [ "$v" -ge 90 ]; then printf alert
  elif [ "$v" -ge 70 ]; then printf warn
  else                       printf ok
  fi
}
# A 0..1 level from hundredths (integer math, no fork): 0 -> 0.00, 100 -> 1.
level() {
  local h=$1
  [ "$h" -lt 0 ] && h=0; [ "$h" -gt 100 ] && h=100
  if [ "$h" -ge 100 ]; then printf 1; else printf '0.%02d' "$h"; fi
}
# Each half of the chip has its own red-green gradient in the sidebar:
#   value_level  = used %                       (0% green -> 100% red)
#   detail_level = share of the window still to wait before the reset
#                  (reset imminent green -> a whole window away red)
limits_item() {  # id label pct resets_at window_secs
  [ -z "$3" ] && return
  local r pct tl="" left
  r=$(fmt_reset "$4"); pct=$(round "$3")
  if [ -n "$4" ]; then
    left=$(( ${4%%.*} - now )); [ "$left" -lt 0 ] && left=0
    tl=$(level $(( left * 100 / $5 )))
  fi
  printf '{"id":"%s","label":"%s","value":"%s%%","detail":"%s","tier":"%s","value_level":%s%s}' \
    "$1" "$2" "$pct" "${r:+↻$r}" "$(pct_tier "$3")" "$(level "$pct")" \
    "${tl:+,\"detail_level\":$tl}"
}
# Every Claude session runs this script, each with the limits from ITS OWN last
# API response -- an idle session reports an older, lower number. So the feed is
# MERGED, never overwritten: within one window (same reset, ±120s jitter) usage
# only grows, so the highest wins; a LATER reset means a new window and wins
# outright; an earlier reset than the stored one is stale and loses. A stored
# window whose reset has passed yields to whatever arrives.
merge_window() {  # new_pct new_at old_pct old_at -> "pct<US>at"
  local np=$1 na=${2%%.*} op=$3 oa=${4%%.*}
  if [ -z "$np" ] || [ -z "$na" ]; then
    # nothing new: keep the stored window unless it has already reset
    if [ -n "$op" ] && [ -n "$oa" ] && [ "$oa" -gt "$now" ]; then printf '%s\037%s' "$op" "$oa"
    else printf '%s\037%s' "$np" "$na"; fi
  elif [ -z "$op" ] || [ -z "$oa" ] || [ "$oa" -le "$now" ] || [ "$na" -gt $(( oa + 120 )) ]; then
    printf '%s\037%s' "$np" "$na"
  elif [ "$na" -lt $(( oa - 120 )) ]; then
    printf '%s\037%s' "$op" "$oa"
  elif [ "${np%%.*}" -ge "${op%%.*}" ]; then
    printf '%s\037%s' "$np" "$na"
  else
    printf '%s\037%s' "$op" "$oa"
  fi
}
if [ -n "$five" ] || [ -n "$week" ]; then
  fdir="$HOME/.metamux/feeds"; sig="$HOME/.metamux/.claude-limits.sig"
  last_ts=0 o5="" o5a="" ow="" owa="" last_sig=""
  [ -r "$sig" ] && IFS=$'\037' read -r last_ts o5 o5a ow owa last_sig <"$sig"
  IFS=$'\037' read -r five five_at <<<"$(merge_window "$five" "$five_at" "$o5" "$o5a")"
  IFS=$'\037' read -r week week_at <<<"$(merge_window "$week" "$week_at" "$ow" "$owa")"
  items=$(limits_item 5h 5h "$five" "$five_at" 18000)
  w=$(limits_item wk wk "$week" "$week_at" 604800)
  [ -n "$w" ] && items="${items:+$items,}$w"
  if [ -n "$items" ] && { [ "$items" != "$last_sig" ] || [ $(( now - ${last_ts:-0} )) -ge 300 ]; }; then
    mkdir -p "$fdir" 2>/dev/null
    tmp=$(mktemp "$fdir/.claude-limits.XXXXXX" 2>/dev/null) && {
      printf '{"v":1,"ts":%s,"stale_after":1800,"items":[%s]}\n' "$now" "$items" >"$tmp" \
        && mv -f "$tmp" "$fdir/claude-limits.json" \
        && printf '%s\037%s\037%s\037%s\037%s\037%s\n' "$now" "$five" "$five_at" "$week" "$week_at" "$items" >"$sig" \
        || rm -f "$tmp"
    }
  fi
fi

# --- PR watch + relay: moved to the metamux sidebar's `dashboard` section (2026-10-16).
#   Feeds: ~/.metamux/feeds/{prs,relay}.json, written by pr-watch.sh and the relay watcher.
#   Previous segments: statusline.sh.bak-20261016-feeds

printf '%s' "$out"
