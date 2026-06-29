#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
units_config="${script_dir}/units.conf"

unit_system="imperial"
critical_c=85
warm_c=66
meter_slots=10

if [[ -f "${units_config}" ]]; then
  # shellcheck disable=SC1090
  source "${units_config}"
fi

case "${unit_system}" in
  metric|celsius)
    temp_unit="C"
    ;;
  *)
    temp_unit="F"
    ;;
esac

read_temp_c() {
  local input

  for input in \
    /sys/class/hwmon/hwmon4/temp1_input \
    /sys/class/hwmon/hwmon4/temp2_input \
    /sys/class/thermal/thermal_zone0/temp
  do
    if [[ -r "$input" ]]; then
      awk '{ printf "%.1f\n", $1 / 1000 }' "$input"
      return 0
    fi
  done

  return 1
}

temp_c="$(read_temp_c)"
temp_c_rounded="$(awk -v c="$temp_c" 'BEGIN { printf "%.0f", c }')"
temp_f="$(awk -v c="$temp_c" 'BEGIN { printf "%.0f", (c * 9 / 5) + 32 }')"

if [[ "${temp_unit}" == "C" ]]; then
  temp="${temp_c_rounded}"
  critical="${critical_c}"
else
  temp="${temp_f}"
  critical="$(awk -v c="$critical_c" 'BEGIN { printf "%.0f", (c * 9 / 5) + 32 }')"
fi

filled_slots="$(awk -v temp="$temp_c" -v critical="$critical_c" -v slots="$meter_slots" '
  BEGIN {
    value = int((temp / critical) * slots + 0.5)
    if (value < 0) value = 0
    if (value > slots) value = slots
    print value
  }
')"
empty_slots=$((meter_slots - filled_slots))

if (( temp_c_rounded >= critical_c )); then
  icon="󱃂"
  status="Hot"
elif (( temp_c_rounded >= warm_c )); then
  icon="󰔏"
  status="Warm"
else
  icon="󰔏"
  status="Normal"
fi

text="${temp}°${temp_unit} ${icon}"

meter=""
for i in $(seq 1 "$meter_slots"); do
  if (( i <= filled_slots )); then
    if (( i <= 5 )); then
      meter+="<span foreground='#5f875f'>■</span>"
    elif (( i <= 8 )); then
      meter+="<span foreground='#ead94d'>■</span>"
    else
      meter+="<span foreground='#d42b5b'>■</span>"
    fi
  else
    meter+="<span foreground='#666666'>■</span>"
  fi
done

tooltip="$(printf 'CPU Temp: %s°%s\nThreshold: %s°%s\nStatus: %s\nMeter: %s' "$temp" "$temp_unit" "$critical" "$temp_unit" "$status" "$meter")"

jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
