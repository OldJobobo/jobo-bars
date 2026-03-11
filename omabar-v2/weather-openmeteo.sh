#!/usr/bin/env bash
set -euo pipefail

# Duvall, WA (98019). Hardcoded to match the previous wttrbar setup.
lat="47.7423"
lon="-121.9857"
tz="America/Los_Angeles"

url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=${tz}&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"

json="$(curl --fail --silent --show-error --max-time 4 "$url")"

weather_code="$(jq -r '.current.weather_code' <<<"$json")"
temp="$(jq -r '.current.temperature_2m | round' <<<"$json")"
high="$(jq -r '.daily.temperature_2m_max[0] | round' <<<"$json")"
low="$(jq -r '.daily.temperature_2m_min[0] | round' <<<"$json")"
rain="$(jq -r '.daily.precipitation_probability_max[0] // 0' <<<"$json")"
sunrise="$(jq -r '.daily.sunrise[0] | sub("^[^T]+T"; "") | .[0:5]' <<<"$json")"
sunset="$(jq -r '.daily.sunset[0] | sub("^[^T]+T"; "") | .[0:5]' <<<"$json")"

describe_weather() {
  case "$1" in
    0) printf '%s|%s\n' "󰖙" "Clear" ;;
    1) printf '%s|%s\n' "󰖔" "Mostly Clear" ;;
    2) printf '%s|%s\n' "󰖐" "Partly Cloudy" ;;
    3) printf '%s|%s\n' "󰖐" "Overcast" ;;
    45|48) printf '%s|%s\n' "󰖑" "Fog" ;;
    51|53|55|56|57) printf '%s|%s\n' "󰖖" "Drizzle" ;;
    61|63|65|66|67|80|81|82) printf '%s|%s\n' "󰖗" "Rain" ;;
    71|73|75|77|85|86) printf '%s|%s\n' "󰖘" "Snow" ;;
    95|96|99) printf '%s|%s\n' "󰖓" "Storm" ;;
    *) printf '%s|%s\n' "󰼰" "Weather" ;;
  esac
}

IFS='|' read -r icon label <<<"$(describe_weather "$weather_code")"

tooltip_lines=()
tooltip_lines+=("${label} ${temp}°F")
tooltip_lines+=("Today: High ${high}°  Low ${low}°")
tooltip_lines+=("Rain ${rain}%")
tooltip_lines+=("Sunrise ${sunrise}  Sunset ${sunset}")
tooltip_lines+=("")
tooltip_lines+=("7-Day Forecast")

while IFS=$'\t' read -r date day_code day_high day_low; do
  IFS='|' read -r day_icon day_label <<<"$(describe_weather "$day_code")"
  day_name="$(date -d "$date" +%a)"
  tooltip_lines+=("${day_name}  ${day_icon}  ${day_high}°/${day_low}°  ${day_label}")
done < <(
  jq -r '
    .daily.time as $time
    | .daily.weather_code as $code
    | .daily.temperature_2m_max as $high
    | .daily.temperature_2m_min as $low
    | range(0; ($time | length))
    | [$time[.], $code[.], ($high[.] | round), ($low[.] | round)]
    | @tsv
  ' <<<"$json"
)

tooltip="$(printf '%s\n' "${tooltip_lines[@]}")"

text="${icon} ${temp}°F"

jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
