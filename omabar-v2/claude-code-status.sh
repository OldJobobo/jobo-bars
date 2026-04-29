#!/usr/bin/env bash

set -euo pipefail

# ── Display text ─────────────────────────────────────────────────────────────
# Tweak the format strings and separator here. Available placeholders:
#   {session_left}   % remaining in current 5h block  (e.g. 43)
#   {session_pct}    % used in current 5h block        (e.g. 57)
#   {session_reset}  local time the 5h block resets    (e.g. 8:00 PM)
#   {session_count}  number of live Claude sessions   (e.g. 3)
#
# Comment out a FMT_ line to hide that part entirely.
SEP=" "
FMT_SESSION="{session_left}% 󰅕 {session_reset}"
# ─────────────────────────────────────────────────────────────────────────────

theme_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_colors="/home/oldjobobo/.config/omarchy/current/theme/colors.css"
icon_template="$theme_dir/assets/claude-ai.svg"
icon_output="$theme_dir/assets/claude-ai-themed.svg"

# Plan limits — non-cache-read tokens (input + output + cache_creation)
# Calibrated from live /usage API: 381,821 tokens = 39% → session limit 978,515
# Validated: 412,279 tokens = 42% (same block, more usage) — consistent
SESSION_LIMIT=978515

# Theme the icon
if [[ -f "$theme_colors" && -f "$icon_template" ]]; then
  _style="$theme_dir/style.css"
  _claude_color="$(awk '/@define-color accent-claude / {print $3; exit}' "$_style")"
  _claude_color="${_claude_color%;}"
  accent="$(awk -v c="${_claude_color#@}" '/@define-color / && $2 == c {print $3; exit}' "$theme_colors")"
  accent="${accent%;}"
  if [[ -n "${accent:-}" ]]; then
    tmp_icon="$(mktemp)"
    sed -e "0,/fill=\"#d97757\"/s//fill=\"$accent\"/" "$icon_template" >"$tmp_icon"
    if [[ ! -f "$icon_output" ]] || ! cmp -s "$tmp_icon" "$icon_output"; then
      mv "$tmp_icon" "$icon_output"
    else
      rm -f "$tmp_icon"
    fi
  fi
fi

# Count active Claude Code sessions by checking live PIDs
session_count=0
for f in "$HOME/.claude/sessions/"*.json; do
  [[ -f "$f" ]] || continue
  pid="$(python3 -c "import json; print(json.load(open('$f')).get('pid',''))" 2>/dev/null)" || continue
  [[ -n "$pid" && -d "/proc/$pid" ]] && session_count=$((session_count + 1)) || true
done

# Locate ccusage binary
_ccusage() {
  local bin
  if command -v ccusage &>/dev/null; then
    ccusage "$@"
    return
  fi
  bin="$(find "$HOME/.npm/_npx" -maxdepth 4 -name 'ccusage' -not -type d \
    2>/dev/null | grep '\.bin/ccusage' | head -1)"
  if [[ -n "$bin" && -x "$bin" ]]; then
    "$bin" "$@"
    return
  fi
  npx --yes ccusage "$@"
}

# Compute percentages locally from ccusage's active 5-hour block.
session_pct=""
session_left=""
session_reset=""
session_tokens=""
session_start=""

if command -v node &>/dev/null; then
  _tmp_b="$(mktemp)"
  _ccusage blocks --json --offline --active 2>/dev/null >"$_tmp_b" || true

  usage_data="$(
    python3 - "$_tmp_b" "$SESSION_LIMIT" <<'PYEOF'
import json, sys
from datetime import datetime

blocks_file = sys.argv[1]
SESSION_LIMIT = int(sys.argv[2])

result = {}

try:
    with open(blocks_file) as f:
        d = json.load(f)
    blocks = [b for b in d.get('blocks', []) if b.get('isActive') and not b.get('isGap')]
    if not blocks:
        raise SystemExit

    active_block = max(blocks, key=lambda b: b.get('startTime', ''))
    tc = active_block.get('tokenCounts', {})
    session_nc = (
        tc.get('inputTokens', 0)
        + tc.get('outputTokens', 0)
        + tc.get('cacheCreationInputTokens', 0)
    )
    session_end = active_block.get('endTime', '')
    block_start = active_block.get('startTime', '')

    if session_nc > 0:
        pct = min(100, round(session_nc / SESSION_LIMIT * 100))
        result['session_pct_used'] = pct
        result['session_left'] = max(0, 100 - pct)
        result['session_tokens'] = session_nc
        if session_end:
            dt = datetime.fromisoformat(session_end.replace('Z', '+00:00'))
            result['session_reset'] = dt.astimezone().strftime('%-I:%M %p')
        if block_start:
            dt = datetime.fromisoformat(block_start.replace('Z', '+00:00'))
            result['session_start'] = dt.astimezone().strftime('%-I:%M %p')
except Exception:
    pass

print(json.dumps(result))
PYEOF
  )" || usage_data=""

  rm -f "$_tmp_b"

  if [[ -n "$usage_data" ]]; then
    session_pct="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('session_pct_used',''))" "$usage_data" 2>/dev/null)"
    session_left="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('session_left',''))" "$usage_data" 2>/dev/null)"
    session_reset="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('session_reset',''))" "$usage_data" 2>/dev/null)"
    session_tokens="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('session_tokens',''))" "$usage_data" 2>/dev/null)"
    session_start="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('session_start',''))" "$usage_data" 2>/dev/null)"
  fi
fi

# Assemble display text from format strings defined at top of script
_fmt() {
  local tmpl="$1"
  tmpl="${tmpl//\{session_left\}/$session_left}"
  tmpl="${tmpl//\{session_pct\}/$session_pct}"
  tmpl="${tmpl//\{session_reset\}/$session_reset}"
  tmpl="${tmpl//\{session_count\}/$session_count}"
  printf '%s' "$tmpl"
}
text_parts=()
[[ -n "$session_left" && -n "${FMT_SESSION:-}" ]] && text_parts+=("$(_fmt "$FMT_SESSION")")

if [[ ${#text_parts[@]} -gt 0 ]]; then
  display_text="$(python3 -c "import sys; sep=sys.argv[1]; print(sep.join(sys.argv[2:]))" "$SEP" "${text_parts[@]}")"
else
  display_text="--"
fi

# Tooltip
tooltip_lines=("Claude Code")
tooltip_lines+=("Sessions: $session_count")
if [[ -n "$session_pct" ]]; then
  line="5h block: ${session_pct}% used"
  [[ -n "$session_reset" ]] && line+=" · resets ${session_reset}"
  tooltip_lines+=("$line")
  [[ -n "$session_tokens" ]] && tooltip_lines+=("Tokens: $(printf "%'d" "$session_tokens") / $(printf "%'d" "$SESSION_LIMIT") counted")
  [[ -n "$session_start" ]] && tooltip_lines+=("Started: $session_start")
fi

tooltip="$(
  IFS=$'\n'
  printf '%s' "${tooltip_lines[*]}"
)"
tooltip_json="$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<<"$tooltip")"

# CSS class
class="normal"
[[ "$session_count" -gt 0 ]] && class="active"
min_left=100
[[ -n "$session_left" && "$session_left" -lt "$min_left" ]] && min_left="$session_left"
[[ "$min_left" -lt 20 ]] && class="low"
[[ "$min_left" -eq 0 ]] && class="over"

printf '{"text":"%s","tooltip":%s,"class":"%s"}\n' \
  "$display_text" "$tooltip_json" "$class"
