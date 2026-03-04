# Changelog

## 0.1.0
- Renamed theme directory from `waffle-cat` to `pillbar-v1`.
- Added `VERSION` file.
- Standardized release version to `0.1.0`; `v1` in the directory name is a variant label, not the package version.
- `config.jsonc`: added `custom/weather.exec-if` guard for `wttrbar`.
- `config.jsonc`: changed clock right-click command to `omarchy-cmd-tzupdate` (from an absolute path).
- `config.jsonc`: removed hardcoded `backlight.device` to rely on Waybar defaults.
- Migrated styling to Omarchy `colors.css` template import.
- Updated palette usage to semantic aliases sourced from Omarchy `colors.css` keys (`@background`, `@foreground`, `@accent`, `@color0..@color15`).
- Kept pill layout/spacing while making colors dynamic with theme changes.
- `style.css`: replaced fixed color definitions with semantic color aliases mapped to Omarchy theme keys.
