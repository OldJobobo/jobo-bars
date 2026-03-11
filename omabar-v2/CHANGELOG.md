# Changelog

## Unreleased

## 0.1.3 - 2026-03-11

### Added
- Added Weather.gov weather alerts to the forecast module, with red pulsing text when an advisory is active.
- Added a theme-local `weather-location.conf` file to make the weather location easier to configure.

### Changed
- Weather location can now be set by place name with cached geocoding, with safe fallback to built-in coordinates if resolution fails.
- Weather module clicks now reuse the same configured forecast location source as the forecast data.

## 0.1.2 - 2026-03-11

### Changed
- Added a right-click action on the theme status module to apply a random Omarchy theme different from the current one.

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
