# Changelog

## Unreleased

## 0.1.1 - 2026-03-11

### Changed
- Replaced the custom MPRIS polling script with Waybar's native `mpris` module.
- Updated the bar styling to target Waybar's built-in `#mpris` states directly.
- Removed the unused `mpris-status.sh` helper script.

## 0.1.0 - 2026-03-11

### Added
- Initial `omabar-v2` release.
- Added custom status scripts for clock, MPRIS, temperature, theme name, and weather modules.
- Added a new top bar layout with centered status modules and tray expander behavior.

### Changed
- Scoped custom script execution to the installed `omabar-v2` theme directory so the release is self-contained.
