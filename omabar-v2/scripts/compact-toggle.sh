#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$THEME_DIR/.cache"
STATE_FILE="$STATE_DIR/compact-mode.state"
CSS_FILE="$SCRIPT_DIR/compact-state-active.css"
NORMAL_CSS="$SCRIPT_DIR/compact-state-normal.css"
COMPACT_CSS="$SCRIPT_DIR/compact-state-compact.css"

mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
  printf 'normal\n' > "$STATE_FILE"
fi

state="$(tr -d '[:space:]' < "$STATE_FILE")"

if [[ "$state" == "compact" ]]; then
  cmp -s "$COMPACT_CSS" "$CSS_FILE" || cp "$COMPACT_CSS" "$CSS_FILE"
  printf '{"text":"󰘔","class":"compact-on","tooltip":"Compact layout: on"}\n'
else
  cmp -s "$NORMAL_CSS" "$CSS_FILE" || cp "$NORMAL_CSS" "$CSS_FILE"
  printf '{"text":"󰘕","class":"compact-off","tooltip":"Compact layout: off"}\n'
fi
