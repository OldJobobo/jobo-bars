#!/usr/bin/env bash
set -euo pipefail

theme_name_file="/home/oldjobobo/.config/omarchy/current/theme.name"
colors_toml="/home/oldjobobo/.config/omarchy/current/theme/colors.toml"

theme_name="$(<"$theme_name_file")"
theme_title="$(sed 's/[-_]/ /g; s/.*/\L&/; s/\b\([a-z]\)/\U\1/g' <<<"$theme_name")"

declare -a colors=()
for i in $(seq 0 15); do
  value="$(sed -nE "s/^color${i}[[:space:]]*=[[:space:]]*\"([^\"]+)\"/\1/p" "$colors_toml" | head -n1)"
  colors+=("${value:-#777777}")
done

line_one=""
line_two=""
for i in $(seq 0 7); do
  line_one+="<span size='x-large' foreground='${colors[$i]}'>■</span> "
done
for i in $(seq 8 15); do
  line_two+="<span size='x-large' foreground='${colors[$i]}'>■</span> "
done

tooltip="$(printf "Theme: %s\n\n%s\n%s" "$theme_title" "$line_one" "$line_two")"

jq -nc --arg text "󰸉 $theme_title" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
