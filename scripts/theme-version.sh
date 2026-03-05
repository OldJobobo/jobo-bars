#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_BASE="$ROOT_DIR/.versioning"
HISTORY_DIR="$STATE_BASE/history"
UNDONE_DIR="$STATE_BASE/undone"
BACKUP_DIR="$STATE_BASE/changelog-backups"
DEFAULT_INIT_VERSION="0.1.0"

MODE=""
SET_VERSION=""
USE_ALL=0
DRY_RUN=0
ASSUME_YES=0
INIT_MISSING=0
LIST_THEMES=0
USE_INTERACTIVE=0

THEME_ARGS=()
BATCH_PATTERNS=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/theme-version.sh                        # interactive mode (requires gum)
  scripts/theme-version.sh --mode patch --theme tilebar-v1
  scripts/theme-version.sh --mode minor --all
  scripts/theme-version.sh --mode set --set-version 1.2.3 --theme pillbar-v1,tilebar-v1
  scripts/theme-version.sh --mode undo

Options:
  --mode <patch|minor|major|set|undo>
  --set-version <x.y.z>        Required when --mode set
  --theme <name[,name2,...]>   Repeatable
  --batch <glob>               Theme-name glob pattern, repeatable (example: '*-v1')
  --all                        Select all discoverable top-level themes
  --init-missing               Initialize missing VERSION as 0.1.0 before applying change
  --list-themes                Print discoverable themes and exit
  --dry-run                    Print actions without writing files
  -y, --yes                    Skip confirmation prompt in CLI mode
  -h, --help                   Show this help text

Notes:
  - A discoverable theme is a top-level directory containing both config.jsonc and style.css.
  - Undo reverts the most recent successful non-dry-run transaction.
USAGE
}

err() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warning: $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

validate_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

version_file() {
  local theme="$1"
  echo "$ROOT_DIR/$theme/VERSION"
}

changelog_file() {
  local theme="$1"
  echo "$ROOT_DIR/$theme/CHANGELOG.md"
}

discover_themes() {
  local d name
  for d in "$ROOT_DIR"/*; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == .* ]] && continue
    if [[ -f "$d/config.jsonc" && -f "$d/style.css" ]]; then
      echo "$name"
    fi
  done | sort
}

split_csv() {
  local raw="$1"
  local IFS=','
  read -r -a _parts <<< "$raw"
  for p in "${_parts[@]}"; do
    [[ -n "$p" ]] && echo "$p"
  done
}

unique_themes() {
  awk '!seen[$0]++'
}

collect_cli_themes() {
  local all_themes
  all_themes="$(discover_themes)"

  if [[ "$USE_ALL" -eq 1 ]]; then
    printf '%s\n' "$all_themes"
  fi

  local t
  for t in "${THEME_ARGS[@]}"; do
    split_csv "$t"
  done

  local pattern name matched
  for pattern in "${BATCH_PATTERNS[@]}"; do
    matched=0
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if [[ "$name" == $pattern ]]; then
        echo "$name"
        matched=1
      fi
    done <<< "$all_themes"
    if [[ "$matched" -eq 0 ]]; then
      warn "No themes matched --batch pattern: $pattern"
    fi
  done | cat
}

increment_version() {
  local version="$1"
  local part="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"

  case "$part" in
    patch)
      patch=$((patch + 1))
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    *)
      err "Invalid increment part: $part"
      ;;
  esac

  echo "$major.$minor.$patch"
}

print_plan() {
  local mode="$1"
  local set_version="$2"
  shift 2
  local themes=("$@")

  echo "Mode: $mode"
  if [[ "$mode" == "set" ]]; then
    echo "Target version: $set_version"
  fi
  echo "Themes (${#themes[@]}): ${themes[*]}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run: yes"
  fi
}

confirm_cli() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

ensure_state_dirs() {
  local probe
  probe=".write-test-$$"
  if mkdir -p "$HISTORY_DIR" "$UNDONE_DIR" "$BACKUP_DIR" >/dev/null 2>&1 \
    && touch "$HISTORY_DIR/$probe" "$UNDONE_DIR/$probe" "$BACKUP_DIR/$probe" >/dev/null 2>&1; then
    rm -f "$HISTORY_DIR/$probe" "$UNDONE_DIR/$probe" "$BACKUP_DIR/$probe" >/dev/null 2>&1 || true
    return 0
  fi

  # Fallback for environments where repository root is not writable.
  STATE_BASE="${TMPDIR:-/tmp}/jobo-bars-versioning-${USER:-user}"
  HISTORY_DIR="$STATE_BASE/history"
  UNDONE_DIR="$STATE_BASE/undone"
  BACKUP_DIR="$STATE_BASE/changelog-backups"
  mkdir -p "$HISTORY_DIR" "$UNDONE_DIR" "$BACKUP_DIR" || err "Unable to create state directory for undo history"
  touch "$HISTORY_DIR/$probe" >/dev/null 2>&1 || err "Fallback history directory is not writable: $HISTORY_DIR"
  touch "$UNDONE_DIR/$probe" >/dev/null 2>&1 || err "Fallback undo directory is not writable: $UNDONE_DIR"
  touch "$BACKUP_DIR/$probe" >/dev/null 2>&1 || err "Fallback changelog backup directory is not writable: $BACKUP_DIR"
  rm -f "$HISTORY_DIR/$probe" "$UNDONE_DIR/$probe" "$BACKUP_DIR/$probe" >/dev/null 2>&1 || true
  warn "Using fallback state directory: $STATE_BASE"
}

extract_unreleased_body() {
  local changelog_path="$1"
  awk '
    BEGIN { in_unreleased=0 }
    /^##[[:space:]]+Unreleased[[:space:]]*$/ { in_unreleased=1; next }
    /^##[[:space:]]+/ {
      if (in_unreleased) exit
    }
    {
      if (in_unreleased) print
    }
  ' "$changelog_path"
}

remove_unreleased_section() {
  local changelog_path="$1"
  awk '
    BEGIN { skipping=0 }
    /^##[[:space:]]+Unreleased[[:space:]]*$/ { skipping=1; next }
    /^##[[:space:]]+/ {
      if (skipping) skipping=0
    }
    {
      if (!skipping) print
    }
  ' "$changelog_path"
}

write_released_changelog() {
  local theme="$1"
  local new_version="$2"
  local backup_tx_dir="$3"
  local changelog_path
  changelog_path="$(changelog_file "$theme")"

  local backup_marker="__NONE__"
  local release_date
  release_date="$(date +%Y-%m-%d)"
  local release_header
  release_header="## $new_version - $release_date"

  if [[ -f "$changelog_path" ]]; then
    if grep -Eq "^##[[:space:]]+$new_version([[:space:]]+-[[:space:]].*)?$" "$changelog_path"; then
      warn "Skipping CHANGELOG update for $theme: section $new_version already exists"
      echo "$backup_marker"
      return 0
    fi

    local backup_path
    backup_path="$backup_tx_dir/$theme.before.md"
    cp "$changelog_path" "$backup_path"
    backup_marker="$backup_path"

    local unreleased_body remainder stripped_remainder
    unreleased_body="$(extract_unreleased_body "$changelog_path")"
    remainder="$(remove_unreleased_section "$changelog_path")"

    if [[ -z "$(printf '%s' "$unreleased_body" | tr -d '[:space:]')" ]]; then
      unreleased_body="- No documented changes."
    fi

    stripped_remainder="$(printf '%s\n' "$remainder" \
      | awk 'NR==1 && /^# Changelog[[:space:]]*$/ { next } { print }' \
      | sed '/./,$!d')"

    {
      echo "# Changelog"
      echo
      echo "## Unreleased"
      echo
      echo "$release_header"
      printf '%s\n' "$unreleased_body"
      if [[ -n "$(printf '%s' "$stripped_remainder" | tr -d '[:space:]')" ]]; then
        echo
        printf '%s\n' "$stripped_remainder"
      fi
    } > "$changelog_path"
  else
    backup_marker="__MISSING__"
    {
      echo "# Changelog"
      echo
      echo "## Unreleased"
      echo
      echo "$release_header"
      echo "- No documented changes."
    } > "$changelog_path"
  fi

  echo "$backup_marker"
}

record_transaction() {
  local record_file="$1"
  shift
  local rows=("$@")

  [[ "${#rows[@]}" -gt 0 ]] || return 0
  ensure_state_dirs
  {
    printf 'timestamp\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'cwd\t%s\n' "$(pwd)"
    printf 'root\t%s\n' "$ROOT_DIR"
    printf '%s\n' '---'
    printf '%s\n' "${rows[@]}"
  } > "$record_file"
}

run_undo() {
  ensure_state_dirs
  local latest
  latest="$(ls -1 "$HISTORY_DIR"/*.tsv 2>/dev/null | sort | tail -n1 || true)"
  [[ -n "$latest" ]] || err "No previous transaction found to undo"

  echo "Undoing transaction: $(basename "$latest")"

  local line
  local in_rows=0
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      in_rows=1
      continue
    fi
    [[ "$in_rows" -eq 1 ]] || continue
    [[ -z "$line" ]] && continue

    local theme old_version _new changelog_backup version_path changelog_path
    IFS=$'\t' read -r theme old_version _new changelog_backup <<< "$line"
    version_path="$(version_file "$theme")"
    changelog_path="$(changelog_file "$theme")"

    if [[ "$old_version" == "__MISSING__" ]]; then
      if [[ -f "$version_path" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[dry-run] remove $theme/VERSION"
        else
          rm -f "$version_path"
          echo "Removed $theme/VERSION"
        fi
      fi
    else
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] set $theme VERSION to $old_version"
      else
        printf '%s\n' "$old_version" > "$version_path"
        echo "Reverted $theme: $old_version"
      fi
    fi

    if [[ "${changelog_backup:-__NONE__}" != "__NONE__" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ "$changelog_backup" == "__MISSING__" ]]; then
          echo "[dry-run] remove $theme/CHANGELOG.md"
        else
          echo "[dry-run] restore $theme/CHANGELOG.md from backup"
        fi
      else
        if [[ "$changelog_backup" == "__MISSING__" ]]; then
          rm -f "$changelog_path"
          echo "Removed $theme/CHANGELOG.md"
        elif [[ -f "$changelog_backup" ]]; then
          cp "$changelog_backup" "$changelog_path"
          echo "Restored $theme/CHANGELOG.md"
        else
          warn "Missing changelog backup for $theme: $changelog_backup"
        fi
      fi
    fi
  done < "$latest"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mv "$latest" "$UNDONE_DIR/$(basename "$latest")"
    echo "Undo complete"
  fi
}

interactive_select_mode() {
  gum choose "patch" "minor" "major" "set" "undo"
}

interactive_select_themes() {
  mapfile -t _discovered < <(discover_themes)
  [[ "${#_discovered[@]}" -gt 0 ]] || err "No themes discovered"

  local scope
  scope="$(gum choose "pick" "batch" "all")"

  case "$scope" in
    all)
      printf '%s\n' "${_discovered[@]}"
      ;;
    pick)
      # Single-select to avoid accidental multi-selection in interactive mode.
      gum choose "${_discovered[@]}"
      ;;
    batch)
      local pattern
      pattern="$(gum input --placeholder "Enter glob pattern (example: *-v1)")"
      [[ -n "$pattern" ]] || err "Batch pattern is required"
      local name matched=0
      for name in "${_discovered[@]}"; do
        if [[ "$name" == $pattern ]]; then
          echo "$name"
          matched=1
        fi
      done
      [[ "$matched" -eq 1 ]] || err "No themes matched pattern: $pattern"
      ;;
    *)
      err "Unsupported scope: $scope"
      ;;
  esac
}

count_missing_versions() {
  local themes=("$@")
  local theme count=0
  for theme in "${themes[@]}"; do
    if [[ ! -f "$(version_file "$theme")" ]]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

has_cli_theme_selectors() {
  [[ "$USE_ALL" -eq 1 || "${#THEME_ARGS[@]}" -gt 0 || "${#BATCH_PATTERNS[@]}" -gt 0 ]]
}

collect_missing_theme_names() {
  local themes=("$@")
  local theme
  for theme in "${themes[@]}"; do
    if [[ ! -f "$(version_file "$theme")" ]]; then
      echo "$theme"
    fi
  done
}

interactive_flow() {
  require_cmd gum

  MODE="$(interactive_select_mode)"

  if [[ "$MODE" == "undo" ]]; then
    return 0
  fi

  if [[ "$MODE" == "set" ]]; then
    SET_VERSION="$(gum input --placeholder "Enter version x.y.z")"
    validate_semver "$SET_VERSION" || err "Invalid version format: $SET_VERSION"
  fi

  if has_cli_theme_selectors; then
    mapfile -t selected_themes < <(collect_cli_themes | unique_themes)
  else
    mapfile -t selected_themes < <(interactive_select_themes | unique_themes)
  fi
  [[ "${#selected_themes[@]}" -gt 0 ]] || err "No themes selected"

  local missing_count init_choice
  missing_count="$(count_missing_versions "${selected_themes[@]}")"
  if [[ "$missing_count" -gt 0 ]]; then
    local missing_names
    missing_names="$(collect_missing_theme_names "${selected_themes[@]}" | paste -sd ', ' -)"
    [[ -n "$missing_names" ]] && echo "Themes missing VERSION: $missing_names"
    init_choice="$(gum choose "skip-missing" "init-missing (0.1.0)")"
    if [[ "$init_choice" == "init-missing (0.1.0)" ]]; then
      INIT_MISSING=1
    fi
  fi

  print_plan "$MODE" "$SET_VERSION" "${selected_themes[@]}"
  gum confirm "Apply changes?" || err "Canceled"

  apply_changes "${selected_themes[@]}"
}

apply_changes() {
  local themes=("$@")
  local transaction_rows=()
  local changed=0
  local skipped_missing=0
  local skipped_non_theme=0
  local skipped_invalid=0
  local unchanged=0
  local transaction_id=""
  local record_file=""
  local backup_tx_dir=""

  if [[ "$DRY_RUN" -eq 0 ]]; then
    ensure_state_dirs
    transaction_id="$(date +%Y%m%d-%H%M%S)-$$"
    record_file="$HISTORY_DIR/$transaction_id.tsv"
    backup_tx_dir="$BACKUP_DIR/$transaction_id"
    mkdir -p "$backup_tx_dir"
  fi

  local theme version_path old_version new_version changelog_backup
  for theme in "${themes[@]}"; do
    version_path="$(version_file "$theme")"

    if [[ ! -f "$ROOT_DIR/$theme/config.jsonc" || ! -f "$ROOT_DIR/$theme/style.css" ]]; then
      warn "Skipping non-theme directory: $theme"
      skipped_non_theme=$((skipped_non_theme + 1))
      continue
    fi

    if [[ -f "$version_path" ]]; then
      old_version="$(tr -d '[:space:]' < "$version_path")"
      validate_semver "$old_version" || {
        warn "Skipping $theme: invalid VERSION content '$old_version'"
        skipped_invalid=$((skipped_invalid + 1))
        continue
      }
    else
      if [[ "$INIT_MISSING" -eq 1 ]]; then
        old_version="__MISSING__"
      else
        warn "Skipping $theme: VERSION missing (use --init-missing to create)"
        skipped_missing=$((skipped_missing + 1))
        continue
      fi
    fi

    case "$MODE" in
      patch|minor|major)
        if [[ "$old_version" == "__MISSING__" ]]; then
          new_version="$(increment_version "$DEFAULT_INIT_VERSION" "$MODE")"
        else
          new_version="$(increment_version "$old_version" "$MODE")"
        fi
        ;;
      set)
        new_version="$SET_VERSION"
        ;;
      *)
        err "Unsupported mode: $MODE"
        ;;
    esac

    if [[ "$old_version" == "$new_version" ]]; then
      echo "$theme unchanged ($new_version)"
      unchanged=$((unchanged + 1))
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] $theme: ${old_version/__MISSING__/missing} -> $new_version"
      echo "[dry-run] $theme: update CHANGELOG.md (Unreleased -> $new_version)"
      changelog_backup="__NONE__"
    else
      printf '%s\n' "$new_version" > "$version_path"
      echo "$theme: ${old_version/__MISSING__/missing} -> $new_version"
      changelog_backup="$(write_released_changelog "$theme" "$new_version" "$backup_tx_dir")"
    fi

    transaction_rows+=("$theme"$'\t'"$old_version"$'\t'"$new_version"$'\t'"${changelog_backup:-__NONE__}")
    changed=$((changed + 1))
  done

  if [[ "$changed" -eq 0 ]]; then
    echo "No changes applied (missing VERSION: $skipped_missing, invalid VERSION: $skipped_invalid, non-theme: $skipped_non_theme, unchanged: $unchanged)"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    record_transaction "$record_file" "${transaction_rows[@]}"
    echo "Recorded undo transaction: ${record_file#$ROOT_DIR/}"
  fi
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ "$#" -ge 2 ]] || err "--mode requires a value"
        MODE="$2"
        shift 2
        ;;
      --set-version)
        [[ "$#" -ge 2 ]] || err "--set-version requires a value"
        SET_VERSION="$2"
        shift 2
        ;;
      --theme)
        [[ "$#" -ge 2 ]] || err "--theme requires a value"
        THEME_ARGS+=("$2")
        shift 2
        ;;
      --batch)
        [[ "$#" -ge 2 ]] || err "--batch requires a value"
        BATCH_PATTERNS+=("$2")
        shift 2
        ;;
      --all)
        USE_ALL=1
        shift
        ;;
      --init-missing)
        INIT_MISSING=1
        shift
        ;;
      --list-themes)
        LIST_THEMES=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -y|--yes)
        ASSUME_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if [[ "$LIST_THEMES" -eq 1 ]]; then
    discover_themes
    exit 0
  fi

  if [[ -z "$MODE" ]]; then
    USE_INTERACTIVE=1
    interactive_flow
    exit 0
  fi

  case "$MODE" in
    patch|minor|major|set|undo)
      ;;
    *)
      err "Invalid --mode value: $MODE"
      ;;
  esac

  if [[ "$MODE" == "undo" ]]; then
    if [[ "$ASSUME_YES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
      confirm_cli "Undo last transaction?" || err "Canceled"
    fi
    run_undo
    exit 0
  fi

  if [[ "$MODE" == "set" ]]; then
    [[ -n "$SET_VERSION" ]] || err "--set-version is required for --mode set"
    validate_semver "$SET_VERSION" || err "Invalid --set-version format: $SET_VERSION"
  fi

  mapfile -t selected_themes < <(collect_cli_themes | unique_themes)
  [[ "${#selected_themes[@]}" -gt 0 ]] || err "No themes selected. Use --theme, --batch, or --all."

  print_plan "$MODE" "$SET_VERSION" "${selected_themes[@]}"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    confirm_cli "Apply version changes?" || err "Canceled"
  fi

  apply_changes "${selected_themes[@]}"
}

main "$@"
