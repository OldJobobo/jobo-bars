#!/usr/bin/env bash
set -euo pipefail

current_background_link="/home/oldjobobo/.config/omarchy/current/background"

format_title() {
  local filename="$1"
  local name="${filename##*/}"

  name="$(sed -E 's/^[0-9]+//; s/^-//; s/\.[^.]+$//; s/-/ /g' <<<"$name")"

  sed 's/.*/\L&/; s/\b\([a-z]\)/\U\1/g' <<<"$name"
}

if [[ -L "$current_background_link" ]]; then
  background_path="$(readlink -f "$current_background_link" 2>/dev/null || true)"
else
  background_path=""
fi

if [[ -n "$background_path" && -f "$background_path" ]]; then
  wallpaper_title="$(format_title "$(basename "$background_path")")"
  tooltip="$(printf "Wallpaper: %s\n\n%s" "$wallpaper_title" "$background_path")"
else
  wallpaper_title="No Wallpaper"
  tooltip="Wallpaper: No Wallpaper\n\nNo active Omarchy background symlink was found."
fi

jq -nc --arg text " $wallpaper_title" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
