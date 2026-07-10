#!/usr/bin/env bash
# Claude Code statusLine script
# Shows: context (tokens + %), rate limits, model, cost, git branch, cwd

input=$(cat)

# --- Context window ---
# used_percentage / remaining come straight from Claude Code.
# The number of tokens currently occupying the context is total_input_tokens
# (current_usage.input_tokens is only the *marginal* input of the last request —
#  the bulk sits in cache_read — so it is NOT the context fill and must not be used here).
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  if [ "$used_int" -ge 80 ]; then
    ctx_color="\033[31m"   # red
  elif [ "$used_int" -ge 60 ]; then
    ctx_color="\033[33m"   # yellow
  else
    ctx_color="\033[0m"    # default
  fi
  if [ -n "$ctx_tok" ] && [ -n "$ctx_size" ]; then
    ctx_part=$(printf "${ctx_color}ctx:%dk/%dk(%d%%)\033[0m" \
      "$((ctx_tok / 1000))" "$((ctx_size / 1000))" "$used_int")
  else
    ctx_part=$(printf "${ctx_color}ctx:%d%%\033[0m" "$used_int")
  fi
else
  ctx_part="ctx:--"
fi

# --- Rate limits ---
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_parts=""
if [ -n "$five_pct" ]; then
  rl_parts="5h:$(printf '%.0f' "$five_pct")%"
fi
if [ -n "$week_pct" ]; then
  [ -n "$rl_parts" ] && rl_parts="$rl_parts "
  rl_parts="${rl_parts}7d:$(printf '%.0f' "$week_pct")%"
fi
[ -z "$rl_parts" ] && rl_parts="quota:--"

# --- Model short name (family + version, e.g. "Opus 4.8", "Sonnet 5") ---
model_id=$(echo "$input" | jq -r '.model.id // empty')
# Take the digits right after the family name: "opus-4-8[1m]"→4.8, "sonnet-5"→5,
# "haiku-4-5-20251001"→4.5 (trailing date/suffix ignored).
ver=$(echo "$model_id" | sed -E 's/.*(opus|sonnet|haiku|fable)-?//I' \
      | grep -oE '^[0-9]+(-[0-9]+)?' | tr '-' '.')
if echo "$model_id" | grep -qi "opus"; then
  model_short="Opus${ver:+ $ver}"
elif echo "$model_id" | grep -qi "sonnet"; then
  model_short="Sonnet${ver:+ $ver}"
elif echo "$model_id" | grep -qi "haiku"; then
  model_short="Haiku${ver:+ $ver}"
elif echo "$model_id" | grep -qi "fable"; then
  model_short="Fable${ver:+ $ver}"
else
  model_short=$(echo "$input" | jq -r '.model.display_name // "?"')
fi
[ -z "$model_short" ] && model_short="?"

# --- Reasoning effort level (low/medium/high/xhigh/max) ---
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && model_short="${model_short} \033[2m·${effort}\033[0m"

# --- Cost (comes directly in the status payload now) ---
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -z "$cost_usd" ]; then
  # Fallback: sum costUSD fields from the transcript (older Claude Code layout)
  transcript=$(echo "$input" | jq -r '.transcript_path // empty')
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    cost_usd=$(grep -o '"costUSD":[0-9.]*' "$transcript" 2>/dev/null \
      | awk -F: '{s+=$2} END {if (s>0) printf "%.6f", s}')
  fi
fi
if [ -n "$cost_usd" ] && [ "$(echo "$cost_usd > 0" | bc -l 2>/dev/null)" = "1" ]; then
  cost_part=$(printf 'cost:$%.2f' "$cost_usd")
else
  cost_part="cost:--"
fi

# --- Lines changed this session ---
add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
del=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
diff_part=""
if [ "$add" != "0" ] || [ "$del" != "0" ]; then
  diff_part=$(printf "\033[32m+%s\033[0m/\033[31m-%s\033[0m" "$add" "$del")
fi

# --- Git branch ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
[ -z "$branch" ] && branch="no-git"

# Short folder name
folder=$(basename "$cwd")

# --- Assemble ---
out=$(printf "%b │ %s │ %b │ %s" "$ctx_part" "$rl_parts" "$model_short" "$cost_part")
[ -n "$diff_part" ] && out=$(printf "%s │ %b" "$out" "$diff_part")
printf "%b │ \033[36m%s\033[0m:\033[1m%s\033[0m\n" "$out" "$branch" "$folder"
