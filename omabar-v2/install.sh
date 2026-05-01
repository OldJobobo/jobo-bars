#!/usr/bin/env bash
# omabar-v2 installer
#
# Curl install (recommended — keeps stdin on terminal for prompts):
#   bash <(curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/install.sh)
#
# Or download first:
#   curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/install.sh -o install.sh && bash install.sh

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$WAYBAR_DIR/omabar-v2-backup-$TIMESTAMP"
MANIFEST="$WAYBAR_DIR/.omabar-v2-manifest"

FILES=(
  config.jsonc
  style.css
  scripts/claude-code-status.sh
  scripts/clock-status.sh
  scripts/codex-weekly-left
  scripts/codex-weekly-status.sh
  scripts/compact-state-active.css
  scripts/compact-state-compact.css
  scripts/compact-state-normal.css
  scripts/compact-toggle.sh
  scripts/compact-toggle-switch.sh
  scripts/temperature-status.sh
  scripts/theme-status.sh
  scripts/wallpaper-status.sh
  scripts/weather-location.conf
  scripts/weather-location-select.sh
  scripts/weather-openmeteo.sh
  assets/claude-ai.svg
  assets/claude-ai-themed.svg
  assets/openai-light.svg
  assets/openai-light-themed.svg
)

# --- color setup ---
if [[ -t 1 ]]; then
  RED=$(tput setaf 1 2>/dev/null || printf '')
  GRN=$(tput setaf 2 2>/dev/null || printf '')
  YEL=$(tput setaf 3 2>/dev/null || printf '')
  CYN=$(tput setaf 6 2>/dev/null || printf '')
  BLD=$(tput bold 2>/dev/null || printf '')
  RST=$(tput sgr0 2>/dev/null || printf '')
else
  RED='' GRN='' YEL='' CYN='' BLD='' RST=''
fi

die()  { printf "${RED}error:${RST} %s\n" "$*" >&2; exit 1; }
ok()   { printf "${GRN}✓${RST} %s\n" "$*"; }
info() { printf "${CYN}→${RST} %s\n" "$*"; }
warn() { printf "${YEL}!${RST} %s\n" "$*"; }

# --- dependency check ---
command -v curl >/dev/null 2>&1 || die "curl is required but not found."

printf '\n%somabar-v2 installer%s\n' "$BLD" "$RST"
printf 'Installing to: %s\n\n' "$WAYBAR_DIR"

# --- discover what needs backing up ---
to_backup=()
for f in "${FILES[@]}"; do
  [[ -f "$WAYBAR_DIR/$f" ]] && to_backup+=("$f")
done

# --- print plan ---
printf '%s%d files to install:%s\n' "$BLD" "${#FILES[@]}" "$RST"
for f in "${FILES[@]}"; do
  printf '  %s\n' "$f"
done

printf '\n'
if [[ ${#to_backup[@]} -gt 0 ]]; then
  printf '%s%d existing files will be backed up before install:%s\n' "$YEL$BLD" "${#to_backup[@]}" "$RST"
  printf '  %s(backup location: %s)%s\n' "$YEL" "$(basename "$BACKUP_DIR")" "$RST"
  for f in "${to_backup[@]}"; do
    printf '  %s\n' "$f"
  done
else
  info "No existing files to back up."
fi

printf '\n'
read -rp "Continue with install? [y/N] " yn
[[ "$yn" =~ ^[Yy] ]] || { printf 'Cancelled.\n'; exit 0; }
printf '\n'

# --- create directories ---
mkdir -p "$WAYBAR_DIR/scripts" "$WAYBAR_DIR/assets"

# --- backup ---
backed_up_name=""
if [[ ${#to_backup[@]} -gt 0 ]]; then
  mkdir -p "$BACKUP_DIR"
  for f in "${to_backup[@]}"; do
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$WAYBAR_DIR/$f" "$BACKUP_DIR/$f"
  done
  backed_up_name="$(basename "$BACKUP_DIR")"
  ok "Backed up ${#to_backup[@]} files → $backed_up_name/"
fi

# --- download files ---
info "Downloading ${#FILES[@]} files from GitHub..."
for f in "${FILES[@]}"; do
  curl -fsSL "$REPO_RAW/$f" -o "$WAYBAR_DIR/$f" \
    || die "Failed to download: $f"
  printf '  %s\n' "$f"
done

# --- set executable permissions ---
find "$WAYBAR_DIR/scripts" -name '*.sh' -exec chmod +x {} \;
ok "Set executable permissions on scripts"

# --- write manifest ---
{
  [[ -n "$backed_up_name" ]] && printf 'BACKUP=%s\n' "$backed_up_name"
  printf '%s\n' "${FILES[@]}"
} > "$MANIFEST"
ok "Wrote install manifest → .omabar-v2-manifest"

# --- weather location setup ---
printf '\n%sWeather location%s\n' "$BLD" "$RST"

weather_conf="$WAYBAR_DIR/scripts/weather-location.conf"
current_loc="$(awk -F'"' '/^location_query=/ {print $2; exit}' "$weather_conf" 2>/dev/null || printf 'not set')"
printf 'Current location: %s\n\n' "$current_loc"
printf 'You can update this any time by running:\n'
printf '  %s\n\n' "$WAYBAR_DIR/scripts/weather-location-select.sh"

read -rp "Configure weather location now? [y/N] " yn
if [[ "$yn" =~ ^[Yy] ]]; then
  printf '\n'
  read -rp "City name (e.g. \"Seattle, WA\" or \"London\"): " city

  if [[ -n "${city:-}" ]]; then
    sys_tz="$(timedatectl show --property=Timezone --value 2>/dev/null \
      || cat /etc/timezone 2>/dev/null \
      || printf '')"
    read -rp "Timezone [${sys_tz:-leave blank to use system default}]: " tz
    tz="${tz:-$sys_tz}"

    cat > "$weather_conf" <<EOF
#!/usr/bin/env bash

# Easiest option: set a place name the geocoder can resolve.
location_query="$city"

# Optional override. Leave blank unless you want to pin exact coordinates.
lat=""
lon=""

# Optional. Leave empty to use the system timezone when available.
tz="$tz"

# Optional. Leave empty to use the default weather.gov URL built from lat/lon.
forecast_url=""
EOF
    ok "Weather location set to: $city${tz:+ ($tz)}"
  else
    warn "No city entered — keeping default location."
  fi
fi

# --- done ---
printf '\n%sInstall complete!%s\n' "$GRN$BLD" "$RST"
[[ -n "$backed_up_name" ]] && printf 'Backup: %s/%s/\n' "$WAYBAR_DIR" "$backed_up_name"
printf '\nTo apply changes, restart waybar:\n'
printf '  pkill waybar && waybar &\n\n'
