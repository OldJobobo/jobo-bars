#!/usr/bin/env bash

set -euo pipefail

theme_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_colors="${OMARCHY_THEME_COLORS:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/current/theme/colors.css}"
icon_template="$theme_dir/assets/openai-light.svg"
icon_output="$theme_dir/assets/openai-light-themed.svg"

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

command -v codex >/dev/null 2>&1 || hide
command -v codex-weekly-left >/dev/null 2>&1 || hide
command -v python3 >/dev/null 2>&1 || hide

if [[ -f "$theme_colors" && -f "$icon_template" ]]; then
  accent="$(awk '/@define-color color5 / {print $3; exit}' "$theme_colors")"
  accent="${accent%;}"

  if [[ -n "${accent:-}" ]]; then
    tmp_icon="$(mktemp)"
    if sed -e "0,/fill=\"#fff\"/s//fill=\"$accent\"/" "$icon_template" >"$tmp_icon"; then
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

output="$(codex-weekly-left 2>/dev/null)" || hide

left="$(printf '%s\n' "$output" | awk -F': ' '/^Weekly limit left:/ {print $2; exit}')"
[[ -n "${left:-}" ]] || hide

left="${left%%%}"
left="${left%%.0}"
[[ "$left" =~ ^[0-9]+([.][0-9]+)?$ ]] || hide

python3 - "$left" "$output" <<'PYEOF'
import json
import sys

left = sys.argv[1]
tooltip = sys.argv[2].strip()
print(json.dumps({
    "text": f"{left}% left",
    "tooltip": tooltip,
    "class": "normal",
}, separators=(",", ":")))
PYEOF
