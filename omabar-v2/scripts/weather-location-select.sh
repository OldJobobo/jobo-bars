#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
location_config="${script_dir}/weather-location.conf"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/omabar-v2"
cache_file="${cache_dir}/weather-location.cache"
search_base='https://geocoding-api.open-meteo.com/v1/search?count=10&format=json&name='

weathercurl=(curl -sS --fail)
if command -v torsocks >/dev/null 2>&1 && ss -tnupl 2>/dev/null | grep -q '127.0.0.1:9050'; then
  weathercurl=(torsocks curl -sS --fail)
fi

gum style --foreground 2 "Looking up locations with ${weathercurl[*]}" >&2
city="$(gum input --placeholder 'Enter city (e.g. London or New York)...')" || exit 1
[[ -z "${city}" ]] && exit 1

search_url="${search_base}$(printf '%s' "${city}" | jq -sRr @uri)"
results="$("${weathercurl[@]}" --connect-timeout 10 "${search_url}" | jq -c '.results[]?')"

if [[ -z "${results}" ]]; then
  gum style --foreground 196 "No locations found for '${city}'." >&2
  exit 1
fi

selection="$(
  printf '%s\n' "${results}" |
    jq -r '"\(.name), \(.admin1 // "") (\(.country)) | \(.latitude),\(.longitude) | \(.timezone)"' |
    fzf --height 40% --reverse --prompt='Select location: '
)"
[[ -z "${selection}" ]] && exit 1

IFS='|,' read -r display_name _ lat lon tz <<<"${selection}"
display_name="${display_name%"${display_name##*[![:space:]]}"}"
lat="${lat// /}"
lon="${lon// /}"
tz="${tz// /}"

cat > "${location_config}" <<EOF
#!/usr/bin/env bash

# Easiest option: set a place name the geocoder can resolve.
location_query=$(printf '%q' "${display_name}")

# Optional override. Leave blank unless you want to pin exact coordinates.
lat=$(printf '%q' "${lat}")
lon=$(printf '%q' "${lon}")

# Optional. Leave empty to use the system timezone when available.
tz=$(printf '%q' "${tz}")

# Optional. Leave empty to use the default weather.gov URL built from lat/lon.
forecast_url=""
EOF

rm -f "${cache_file}"

gum style --foreground 212 "Updated ${location_config} for ${display_name}" >&2
printf 'location_query="%s"\nlat="%s"\nlon="%s"\ntz="%s"\n' "${display_name}" "${lat}" "${lon}" "${tz}"
