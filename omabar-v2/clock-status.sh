#!/usr/bin/env bash
set -euo pipefail

day_num="$(date +%-d)"
case "$day_num" in
  1|21|31) suffix="st" ;;
  2|22) suffix="nd" ;;
  3|23) suffix="rd" ;;
  *) suffix="th" ;;
esac

bar_text="$(printf '%s %s%s %s' "$(date +%a)" "$day_num" "$suffix" "$(date +"%I:%M %p")")"

month_header="$(date +"%B %Y")"
calendar_lines="$(cal)"
weekday_line="$(sed -n '2p' <<<"$calendar_lines")"
date_lines="$(sed -n '3,$p' <<<"$calendar_lines")"
highlighted_dates="$(sed -E "s/(^|[[:space:]])(${day_num})([[:space:]]|$)/\1<span foreground='#c0daf6' weight='bold'>\2<\/span>\3/g" <<<"$date_lines")"

tooltip="$(printf "<span foreground='#c9a554' weight='bold'>%s</span>\n\n<span font_family='monospace'><span foreground='#ab9191'>%s</span>\n%s</span>" "$month_header" "$weekday_line" "$highlighted_dates")"

jq -nc --arg text "$bar_text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
