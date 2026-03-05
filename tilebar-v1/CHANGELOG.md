# Changelog

## 0.1.1
- Added `custom/voxtype` support to `config.jsonc` using Omarchy base module behavior.
- Added `#custom-voxtype` styling so it matches existing tilebar module spacing, hover, and chip visuals.

## 0.1.0
- Added `VERSION` file.
- Standardized release version to `0.1.0`; `v1` in the directory name is a variant label, not the package version.
- Added `exec-if` guard for `wttrbar` weather module.
- Fixed center panel visibility on empty workspaces by removing CSS hide behavior for `.modules-center`.
- Kept `hyprland/window` visible on empty workspaces by rewriting the empty-window placeholder to `Desktop`.
