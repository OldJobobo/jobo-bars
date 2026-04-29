#!/usr/bin/env bash

set -euo pipefail

# Display format. Available placeholders:
#   {session_left}   percent remaining in the current 5h block
#   {session_pct}    percent used in the current 5h block
#   {session_reset}  local reset time for the current 5h block
#   {session_count}  number of live Claude Code sessions
SEP=" "
FMT_SESSION="{session_left}% 󰅕 {session_reset}"

theme_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_colors="${OMARCHY_THEME_COLORS:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/current/theme/colors.css}"
icon_template="$theme_dir/assets/claude-ai.svg"
icon_output="$theme_dir/assets/claude-ai-themed.svg"

SESSION_LIMIT="${CLAUDE_CODE_SESSION_LIMIT:-978515}"

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

command -v python3 >/dev/null 2>&1 || hide
command -v claude >/dev/null 2>&1 || hide
[[ "$SESSION_LIMIT" =~ ^[0-9]+$ ]] || hide
(( SESSION_LIMIT > 0 )) || hide

ccusage_bin=""
if command -v ccusage >/dev/null 2>&1; then
  ccusage_bin="$(command -v ccusage)"
elif [[ -d "$HOME/.npm/_npx" ]]; then
  ccusage_bin="$(find "$HOME/.npm/_npx" -maxdepth 5 -path '*/.bin/ccusage' -type f -executable 2>/dev/null | sort | tail -n 1)"
fi
[[ -n "$ccusage_bin" && -x "$ccusage_bin" ]] || hide

if [[ -f "$theme_colors" && -f "$icon_template" ]]; then
  style_file="$theme_dir/style.css"
  claude_color="$(awk '/@define-color accent-claude / {print $3; exit}' "$style_file" 2>/dev/null)"
  claude_color="${claude_color%;}"
  accent="$(awk -v color_name="${claude_color#@}" '/@define-color / && $2 == color_name {print $3; exit}' "$theme_colors")"
  accent="${accent%;}"

  if [[ -n "${accent:-}" ]]; then
    tmp_icon="$(mktemp)"
    if sed -e "0,/fill=\"#d97757\"/s//fill=\"$accent\"/" "$icon_template" >"$tmp_icon"; then
      if [[ ! -f "$icon_output" ]] || ! cmp -s "$tmp_icon" "$icon_output"; then
        mv "$tmp_icon" "$icon_output" 2>/dev/null || rm -f "$tmp_icon"
      else
        rm -f "$tmp_icon"
      fi
    else
      rm -f "$tmp_icon"
    fi
  fi
fi

session_count=0
if [[ -d "$HOME/.claude/sessions" ]]; then
  while IFS= read -r session_file; do
    pid="$(python3 - "$session_file" <<'PYEOF' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        print(json.load(f).get("pid", ""))
except Exception:
    pass
PYEOF
)"
    [[ -n "$pid" && -d "/proc/$pid" ]] && session_count=$((session_count + 1))
  done < <(find "$HOME/.claude/sessions" -maxdepth 1 -type f -name '*.json' 2>/dev/null)
fi

tmp_blocks="$(mktemp)"
cleanup() {
  rm -f "$tmp_blocks"
}
trap cleanup EXIT

if command -v timeout >/dev/null 2>&1; then
  timeout 5 "$ccusage_bin" blocks --json --offline --active >"$tmp_blocks" 2>/dev/null || hide
else
  "$ccusage_bin" blocks --json --offline --active >"$tmp_blocks" 2>/dev/null || hide
fi

python3 - "$tmp_blocks" "$SESSION_LIMIT" "$session_count" "$SEP" "$FMT_SESSION" <<'PYEOF'
import json
import sys
from datetime import datetime

blocks_file = sys.argv[1]
session_limit = int(sys.argv[2])
session_count = int(sys.argv[3])
sep = sys.argv[4]
fmt_session = sys.argv[5]

def hide():
    print('{"text":"","tooltip":"","class":"hidden"}')
    raise SystemExit

try:
    with open(blocks_file, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    hide()

blocks = [
    block for block in data.get("blocks", [])
    if block.get("isActive") and not block.get("isGap")
]
if not blocks:
    hide()

active_block = max(blocks, key=lambda block: block.get("startTime", ""))
token_counts = active_block.get("tokenCounts", {})
session_tokens = (
    int(token_counts.get("inputTokens", 0) or 0)
    + int(token_counts.get("outputTokens", 0) or 0)
    + int(token_counts.get("cacheCreationInputTokens", 0) or 0)
)
if session_tokens <= 0:
    hide()

session_pct = min(100, round(session_tokens / session_limit * 100))
session_left = max(0, 100 - session_pct)

def local_time(value):
    if not value:
        return ""
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone().strftime("%-I:%M %p")
    except Exception:
        return ""

session_reset = local_time(active_block.get("endTime", ""))
session_start = local_time(active_block.get("startTime", ""))

values = {
    "session_left": str(session_left),
    "session_pct": str(session_pct),
    "session_reset": session_reset,
    "session_count": str(session_count),
}

text_parts = []
if fmt_session:
    text = fmt_session
    for key, value in values.items():
        text = text.replace("{" + key + "}", value)
    text_parts.append(" ".join(text.split()))

if not text_parts:
    hide()

tooltip_lines = [
    "Claude Code",
    f"Sessions: {session_count}",
    f"5h block: {session_pct}% used" + (f" - resets {session_reset}" if session_reset else ""),
    f"Tokens: {session_tokens:,} / {session_limit:,} counted",
]
if session_start:
    tooltip_lines.append(f"Started: {session_start}")

css_class = "active" if session_count > 0 else "normal"
if session_left < 20:
    css_class = "low"
if session_left == 0:
    css_class = "over"

print(json.dumps({
    "text": sep.join(text_parts),
    "tooltip": "\n".join(tooltip_lines),
    "class": css_class,
}, separators=(",", ":")))
PYEOF
