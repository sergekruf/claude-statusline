#!/usr/bin/env bash
# Claude Code statusLine script
# Shows: context (tokens + %), rate limits, model+effort, lines changed,
#        Claude Code update indicator, git branch, cwd

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

# --- Lines changed this session ---
add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
del=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
diff_part=""
if [ "$add" != "0" ] || [ "$del" != "0" ]; then
  diff_part=$(printf "\033[32m+%s\033[0m/\033[31m-%s\033[0m" "$add" "$del")
fi

# --- Claude Code update check ---
# Compares the running version against the newest on the user's release channel
# (autoUpdatesChannel in settings; "stable" by default) via the same source the native
# installer uses — https://downloads.claude.ai/claude-code-releases/<channel>. NOTE: npm's
# "latest" tracks the `latest` channel, so a stable user must NOT be compared against it.
# The lookup runs in the BACKGROUND at most once every 6h and is cached, so rendering never
# blocks on the network. The segment appears ONLY when a newer version exists (yellow "vX↑Y").
cc_ver=$(echo "$input" | jq -r '.version // empty')
ver_part=""
if [ -n "$cc_ver" ]; then
  conf_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  channel=$(jq -r '.autoUpdatesChannel // "stable"' "$conf_dir/settings.json" 2>/dev/null)
  case "$channel" in ""|null) channel="stable";; esac
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  cache_file="$cache_dir/latest-$channel"
  if command -v curl >/dev/null 2>&1; then
    nows=$(date +%s)
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
    if [ ! -s "$cache_file" ] || [ $((nows - mtime)) -gt 21600 ]; then
      mkdir -p "$cache_dir"
      # channel file is a bare version string; reject non-version content (HTML error pages)
      ( curl -fsSL --max-time 4 "https://downloads.claude.ai/claude-code-releases/$channel" \
          | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?' > "$cache_file.tmp" 2>/dev/null \
          && mv "$cache_file.tmp" "$cache_file" ) >/dev/null 2>&1 &
    fi
  fi
  latest=""; [ -s "$cache_file" ] && latest=$(cat "$cache_file" 2>/dev/null)
  if [ -n "$latest" ] && [ "$latest" != "$cc_ver" ] \
     && [ "$(printf '%s\n%s\n' "$cc_ver" "$latest" | sort -V 2>/dev/null | tail -1)" = "$latest" ]; then
    ver_part=$(printf "\033[33mv%s↑%s\033[0m" "$cc_ver" "$latest")   # shown only when an update is available
  fi
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
out=$(printf "%b │ %s │ %b" "$ctx_part" "$rl_parts" "$model_short")
[ -n "$diff_part" ] && out=$(printf "%s │ %b" "$out" "$diff_part")
[ -n "$ver_part" ] && out=$(printf "%s │ %b" "$out" "$ver_part")
printf "%b │ \033[36m%s\033[0m:\033[1m%s\033[0m\n" "$out" "$branch" "$folder"
