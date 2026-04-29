#!/usr/bin/env bash

set -euo pipefail

theme_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_colors="/home/oldjobobo/.config/omarchy/current/theme/colors.css"
icon_template="$theme_dir/assets/openai-light.svg"
icon_output="$theme_dir/assets/openai-light-themed.svg"

if [[ -f "$theme_colors" && -f "$icon_template" ]]; then
  accent="$(awk '/@define-color color5 / {print $3; exit}' "$theme_colors")"
  accent="${accent%;}"

  if [[ -n "${accent:-}" ]]; then
    tmp_icon="$(mktemp)"
    sed \
      -e "0,/fill=\"#fff\"/s//fill=\"$accent\"/" \
      "$icon_template" > "$tmp_icon"

    if [[ ! -f "$icon_output" ]] || ! cmp -s "$tmp_icon" "$icon_output"; then
      mv "$tmp_icon" "$icon_output"
    else
      rm -f "$tmp_icon"
    fi
  fi
fi

if ! output="$(codex-weekly-left 2>/dev/null)"; then
  printf '%s\n' '{"text":"--% left","tooltip":"codex-weekly-left failed","class":"fallback"}'
  exit 0
fi

left="$(printf '%s\n' "$output" | awk -F': ' '/^Weekly limit left:/ {print $2; exit}')"

if [[ -z "${left:-}" ]]; then
  printf '%s\n' '{"text":"--% left","tooltip":"Weekly limit data unavailable","class":"fallback"}'
  exit 0
fi

left="${left%%%}"
left="${left%%.0}"
tooltip="$(printf '%s\n' "$output" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"

printf '{"text":"%s%% left","tooltip":%s,"class":"normal"}\n' "$left" "$tooltip"
