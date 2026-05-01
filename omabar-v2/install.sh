#!/usr/bin/env bash
# omabar-v2 installer
#
# Fresh install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/install.sh)
#
# Update (preserves config.jsonc, style.css, weather-location.conf):
#   bash <(curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/install.sh) --update
#
# Update and also replace preserved files:
#   bash <(curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/install.sh) --update --force

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$WAYBAR_DIR/omabar-v2-backup-$TIMESTAMP"
MANIFEST="$WAYBAR_DIR/.omabar-v2-manifest"

# Files preserved in --update mode (user configs unlikely to want overwritten)
USER_FILES=(
  config.jsonc
  style.css
  scripts/weather-location.conf
)

ALL_FILES=(
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

# --- parse flags ---
UPDATE=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE=true ;;
    --force)  FORCE=true ;;
  esac
done

# Build the file list for this run
FILES=()
SKIPPED=()
for f in "${ALL_FILES[@]}"; do
  if $UPDATE && ! $FORCE; then
    skip=false
    for u in "${USER_FILES[@]}"; do
      [[ "$f" == "$u" ]] && skip=true && break
    done
    if $skip && [[ -f "$WAYBAR_DIR/$f" ]]; then
      SKIPPED+=("$f")
      continue
    fi
  fi
  FILES+=("$f")
done

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

if $UPDATE; then
  printf '\n%somabar-v2 update%s\n' "$BLD" "$RST"
else
  printf '\n%somabar-v2 installer%s\n' "$BLD" "$RST"
fi
printf 'Target: %s\n\n' "$WAYBAR_DIR"

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

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  printf '\n%s%d user files preserved (use --force to overwrite):%s\n' "$CYN$BLD" "${#SKIPPED[@]}" "$RST"
  for f in "${SKIPPED[@]}"; do
    printf '  %s\n' "$f"
  done
fi

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
if $UPDATE; then
  read -rp "Continue with update? [y/N] " yn
else
  read -rp "Continue with install? [y/N] " yn
fi
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
chmod +x "$WAYBAR_DIR/scripts/codex-weekly-left" 2>/dev/null || true
ok "Set executable permissions on scripts"

# --- write manifest ---
{
  [[ -n "$backed_up_name" ]] && printf 'BACKUP=%s\n' "$backed_up_name"
  printf '%s\n' "${ALL_FILES[@]}"
} > "$MANIFEST"
ok "Wrote install manifest → .omabar-v2-manifest"

# --- weather location setup (fresh install only) ---
if ! $UPDATE; then
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
fi

# --- done ---
printf '\n'
if $UPDATE; then
  printf '%sUpdate complete!%s\n' "$GRN$BLD" "$RST"
  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    info "Your config files were preserved. Use --force to overwrite them on next update."
  fi
else
  printf '%sInstall complete!%s\n' "$GRN$BLD" "$RST"
fi
[[ -n "$backed_up_name" ]] && printf 'Backup: %s/%s/\n' "$WAYBAR_DIR" "$backed_up_name"
printf '\nTo apply changes, restart waybar:\n'
printf '  pkill waybar && waybar &\n\n'
