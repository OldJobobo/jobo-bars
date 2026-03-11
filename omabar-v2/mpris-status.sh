#!/usr/bin/env bash
set -euo pipefail

metadata="$(playerctl metadata --format '{{status}}|{{playerName}}|{{artist}}|{{title}}' 2>/dev/null || true)"

if [[ -z "$metadata" ]]; then
  jq -nc '{text:"", class:"empty", tooltip:""}'
  exit 0
fi

IFS='|' read -r status player artist title <<<"$metadata"

case "$status" in
  Playing) icon=""; class="playing" ;;
  Paused) icon=""; class="paused" ;;
  *) icon=""; class="stopped" ;;
esac

if [[ -n "$artist" && -n "$title" ]]; then
  line="$artist - $title"
elif [[ -n "$title" ]]; then
  line="$title"
elif [[ -n "$artist" ]]; then
  line="$artist"
else
  line="$player"
fi

tooltip="$(printf '%s\n%s' "$player" "$line")"

jq -nc --arg text "$icon $line" --arg class "$class" --arg tooltip "$tooltip" \
  '{text:$text, class:$class, tooltip:$tooltip}'
