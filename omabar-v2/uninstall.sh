#!/usr/bin/env bash
# omabar-v2 uninstaller
#
# Run directly:
#   bash <(curl -fsSL https://raw.githubusercontent.com/OldJobobo/jobo-bars/master/omabar-v2/uninstall.sh)
#
# Or if you have the file locally:
#   bash uninstall.sh

set -euo pipefail

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
MANIFEST="$WAYBAR_DIR/.omabar-v2-manifest"

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

printf '\n%somabar-v2 uninstaller%s\n\n' "$BLD" "$RST"

[[ -f "$MANIFEST" ]] || die "No install manifest found at $MANIFEST
       Was omabar-v2 installed with install.sh? If you installed manually,
       remove files from $WAYBAR_DIR by hand."

# --- read manifest ---
backup_name=""
files=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" == BACKUP=* ]]; then
    backup_name="${line#BACKUP=}"
  else
    files+=("$line")
  fi
done < "$MANIFEST"

backup_dir=""
[[ -n "$backup_name" ]] && backup_dir="$WAYBAR_DIR/$backup_name"

# --- count files that are actually present ---
present=()
for f in "${files[@]}"; do
  [[ -f "$WAYBAR_DIR/$f" ]] && present+=("$f")
done

# --- print plan ---
printf '%s%d files to remove from %s:%s\n' "$BLD" "${#present[@]}" "$WAYBAR_DIR" "$RST"
for f in "${present[@]}"; do
  printf '  %s\n' "$f"
done

if [[ "${#present[@]}" -lt "${#files[@]}" ]]; then
  warn "$((${#files[@]} - ${#present[@]})) manifest files already absent — skipping those."
fi

# --- backup / restore prompt ---
restore=false
printf '\n'
if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
  printf '%sBackup available:%s %s\n' "$YEL" "$RST" "$(basename "$backup_dir")"
  read -rp "Restore backup after uninstall? [y/N] " yn
  [[ "$yn" =~ ^[Yy] ]] && restore=true
else
  warn "No backup found — removed files cannot be automatically restored."
fi

printf '\n'
read -rp "Continue with uninstall? [y/N] " yn
[[ "$yn" =~ ^[Yy] ]] || { printf 'Cancelled.\n'; exit 0; }
printf '\n'

# --- remove files ---
removed=0
for f in "${present[@]}"; do
  rm -f "$WAYBAR_DIR/$f"
  (( removed++ )) || true
done
ok "Removed $removed files"

# --- clean up empty directories ---
for dir in "$WAYBAR_DIR/scripts" "$WAYBAR_DIR/assets"; do
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir"
    ok "Removed empty directory: $(basename "$dir")/"
  fi
done

# --- remove manifest ---
rm -f "$MANIFEST"
ok "Removed install manifest"

# --- restore backup ---
if $restore && [[ -d "$backup_dir" ]]; then
  info "Restoring backup..."
  while IFS= read -r src; do
    rel="${src#"$backup_dir"/}"
    dest="$WAYBAR_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    printf '  %s\n' "$rel"
  done < <(find "$backup_dir" -type f | sort)
  ok "Restored backup from $(basename "$backup_dir")"
fi

# --- done ---
printf '\n%sUninstall complete.%s\n' "$GRN$BLD" "$RST"
if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
  printf 'Backup preserved at: %s\n' "$backup_dir"
  printf 'Remove it manually when no longer needed.\n'
fi
printf '\nTo apply changes, restart waybar:\n'
printf '  pkill waybar && waybar &\n\n'
