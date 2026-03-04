# Repository Guidelines

## Project Structure & Module Organization
This repository contains Waybar themes for Omarchy. Each theme is a top-level directory such as `tilebar-v1/`, `pillbar-v1/`, or `miasma/`.

Standard files per theme:
- `config.jsonc`: module layout, actions, polling intervals, and behavior.
- `style.css`: GTK-compatible Waybar CSS.
- Optional theme-local files: `assets/`, `scripts/`, `VERSION`, `CHANGELOG.md`.

Keep all assets and helper scripts inside the same theme directory. Do not commit live user config from `~/.config/waybar/`.

## Build, Test, and Development Commands
There is no build step; work is file-based and validated at runtime.

Useful commands:
- `ls -1`: list available themes at repository root.
- `rg --files <theme-dir>`: quickly list files in a theme.
- `rg -n "<pattern>" <theme-dir>`: search module names, CSS selectors, or commands.
- `omarchy-restart-waybar`: reload Waybar after edits.

Typical local loop:
1. Symlink theme to `~/.config/waybar/themes/<theme-name>`.
2. Select/apply it via your Omarchy workflow.
3. Run `omarchy-restart-waybar` and verify behavior visually.

## Coding Style & Naming Conventions
- Use 2-space indentation in `config.jsonc` and `style.css`.
- Keep existing formatting/key order unless a change requires restructuring.
- Use GTK-safe CSS only; avoid unsupported web CSS features.
- Theme directories use lowercase kebab-case (for example `grimdark-solarized`).
- Prefer Omarchy theme imports (`../omarchy/current/theme/colors.css` or `waybar.css`) over hardcoded absolute user paths.

## Testing Guidelines
- Ensure JSONC remains valid after changes.
- Verify module render, tooltip content, click handlers, and tray behavior.
- Check empty workspace behavior and warning/active states (battery, recording, idle).
- Check both normal and compact/narrow bar states when the theme supports them.
- For shared pattern changes, spot-check at least 2-3 different themes.

## Commit & Pull Request Guidelines
- Use focused commits with `type(scope): summary` (example: `fix(tilebar-v1): preserve center modules on empty workspace`).
- Keep one theme or one cross-theme concern per commit.
- PRs should include:
- affected theme directories,
- short change rationale,
- before/after screenshots (or GIF),
- manual verification notes (including `omarchy-restart-waybar`).
