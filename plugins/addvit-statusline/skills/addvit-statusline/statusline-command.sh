#!/usr/bin/env bash
# Claude Code analytics dashboard — compact single-line status
# Shows: model, context bar/%, used/total tokens, session tokens,
# API rate-limit windows (5h/7d) with live countdown to reset, cwd, git branch.

# ── Constants ────────────────────────────────────────────────────────────────
BAR_WIDTH=8          # filled+empty chars per bar
SEP=" \033[2m│\033[0m "   # dim pipe separator

# ── Read stdin once ──────────────────────────────────────────────────────────
input=$(cat)

# ── Extract fields from JSON ─────────────────────────────────────────────────
session_id=$(echo "$input"  | jq -r '.session_id // ""')
raw_cwd=$(echo "$input"     | jq -r '.cwd // .workspace.current_dir // "."')
model_full=$(echo "$input"  | jq -r '.model.display_name // ""')
ctx_used=$(echo "$input"    | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input"    | jq -r '.context_window.context_window_size // empty')
cur_in=$(echo "$input"      | jq -r '.context_window.current_usage.input_tokens // empty')
cur_out=$(echo "$input"     | jq -r '.context_window.current_usage.output_tokens // empty')
sess_in=$(echo "$input"     | jq -r '.context_window.total_input_tokens // empty')
sess_out=$(echo "$input"    | jq -r '.context_window.total_output_tokens // empty')
rl_5h=$(echo "$input"       | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_7d=$(echo "$input"       | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ── Shorten model name: keep only "Name X.Y" after last space-separated brand─
# e.g. "Claude 3.5 Sonnet" -> "Sonnet 3.5"  /  "Claude Sonnet 4.6" -> "Sonnet 4.6"
shorten_model() {
  local m="$1"
  # Remove leading "Claude " prefix
  m="${m#Claude }"
  echo "$m"
}
model_short=$(shorten_model "$model_full")

now_epoch=$(date +%s)

# ── Helper: format token count as k-string ───────────────────────────────────
fmt_k() {
  local n="$1"
  [ -z "$n" ] || [ "$n" = "0" ] && { echo "0"; return; }
  awk "BEGIN { x=$n/1000; if(x>=10) printf \"%.0fk\",x; else printf \"%.1fk\",x }"
}

# ── Helper: render an ASCII bar ──────────────────────────────────────────────
# ascii_bar <percent_float> <width>
ascii_bar() {
  local pct="$1" w="${2:-$BAR_WIDTH}"
  [ -z "$pct" ] && { printf '%*s' "$w" '' | tr ' ' '░'; return; }
  awk -v p="$pct" -v w="$w" 'BEGIN {
    filled = int(p/100*w + 0.5)
    if (filled > w) filled = w
    for (i=0;i<filled;i++) printf "\xe2\x96\x88"
    for (i=filled;i<w;i++) printf "\xe2\x96\x91"
  }'
}

# ── Helper: format a duration in seconds ─────────────────────────────────────
# >=1d  → "1d2h"      (day+hour — always far from reset, no need for finer)
# <1d   → "H:MM:SS"   (live ticker, ticks every refresh)
#         "MM:SS"     (under 1h, same format, drop leading 0h)
#         "0:SS"      (under 1m)
# ≤0    → "0:00"
fmt_remaining() {
  local secs="$1"
  [ -z "$secs" ] && { echo ""; return; }
  if [ "$secs" -le 0 ]; then
    echo "0:00"
    return
  fi
  local days=$(( secs / 86400 ))
  local hours=$(( (secs % 86400) / 3600 ))
  local mins=$(( (secs % 3600) / 60 ))
  local ss=$(( secs % 60 ))
  if [ "$days" -gt 0 ]; then
    printf "%dd%dh" "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf "%d:%02d:%02d" "$hours" "$mins" "$ss"
  else
    printf "%d:%02d" "$mins" "$ss"
  fi
}

# ── Helper: pick color escape by percentage ───────────────────────────────────
pct_color() {
  local p="$1"
  [ -z "$p" ] && { echo "\033[0m"; return; }
  local pi; pi=$(printf '%.0f' "$p")
  if   [ "$pi" -ge 80 ]; then echo "\033[31m"   # red
  elif [ "$pi" -ge 50 ]; then echo "\033[33m"   # yellow
  else                        echo "\033[36m"   # cyan
  fi
}

# ── Build parts array ────────────────────────────────────────────────────────
parts=()

# 1. Model name (magenta)
if [ -n "$model_short" ]; then
  printf -v p "\033[35m%s\033[0m" "$model_short"
  parts+=("$p")
fi

# 2. Context % with ASCII bar (color-coded)
if [ -n "$ctx_used" ]; then
  used_int=$(printf '%.0f' "$ctx_used")
  col=$(pct_color "$ctx_used")
  bar=$(ascii_bar "$ctx_used" "$BAR_WIDTH")
  printf -v p "${col}%s %d%%\033[0m" "$bar" "$used_int"
  parts+=("$p")
fi

# 3. used/total in k (dim white)
if [ -n "$cur_in" ] && [ -n "$ctx_size" ]; then
  used_toks=$(( cur_in + ${cur_out:-0} ))
  printf -v p "\033[37m%s/%s\033[0m" "$(fmt_k "$used_toks")" "$(fmt_k "$ctx_size")"
  parts+=("$p")
fi

# 4. Session tokens: cumulative input+output for this session (dim yellow)
if [ -n "$sess_in" ] || [ -n "$sess_out" ]; then
  st=$(( ${sess_in:-0} + ${sess_out:-0} ))
  if [ "$st" -gt 0 ]; then
    printf -v p "\033[33msess:%s\033[0m" "$(fmt_k "$st")"
    parts+=("$p")
  fi
fi

# 5. Rate-limit windows from API (5h / 7d) — shown when available
#    Formatted as "5h:23% (2:33:05)" where the parenthesised value is the
#    time remaining until the window resets.
if [ -n "$rl_5h" ] || [ -n "$rl_7d" ]; then
  rl_str=""
  if [ -n "$rl_5h" ]; then
    pi_5h=$(printf '%.0f' "$rl_5h")
    col_r=$(pct_color "$rl_5h")
    rl_str+="${col_r}5h:${pi_5h}%"
    if [ -n "$rl_5h_reset" ]; then
      rem_fmt=$(fmt_remaining $(( rl_5h_reset - now_epoch )))
      [ -n "$rem_fmt" ] && rl_str+=" \033[2m(${rem_fmt})\033[0m${col_r}"
    fi
    rl_str+="\033[0m"
  fi
  if [ -n "$rl_7d" ]; then
    [ -n "$rl_str" ] && rl_str+=" "
    pi_7d=$(printf '%.0f' "$rl_7d")
    col_r=$(pct_color "$rl_7d")
    rl_str+="${col_r}7d:${pi_7d}%"
    if [ -n "$rl_7d_reset" ]; then
      rem_fmt=$(fmt_remaining $(( rl_7d_reset - now_epoch )))
      [ -n "$rem_fmt" ] && rl_str+=" \033[2m(${rem_fmt})\033[0m${col_r}"
    fi
    rl_str+="\033[0m"
  fi
  [ -n "$rl_str" ] && parts+=("$rl_str")
fi

# 6. Directory (blue, ~ substitution)
home_dir="$HOME"
display_cwd="$raw_cwd"
if [ -n "$home_dir" ] && [[ "$display_cwd" == "$home_dir"* ]]; then
  display_cwd="~${display_cwd#$home_dir}"
fi
printf -v p "\033[34m%s\033[0m" "$display_cwd"
parts+=("$p")

# 7. Git branch (green)
branch=""
if git -C "$raw_cwd" --no-optional-locks rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
  branch=$(git -C "$raw_cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi
if [ -n "$branch" ]; then
  printf -v p "\033[32m(%s)\033[0m" "$branch"
  parts+=("$p")
fi

# ── Render ───────────────────────────────────────────────────────────────────
printf "%b" "${parts[0]}"
for part in "${parts[@]:1}"; do
  printf "${SEP}%b" "$part"
done
printf "\n"
