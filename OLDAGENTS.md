# Repository Guidelines

## Project Structure & Module Organization
This repository stores Waybar themes for Omarchy. Each theme lives in its own top-level directory (for example, `batman/`, `miasma/`, `omarchy/`).

Expected files per theme:
- `config.jsonc`: Waybar module layout and behavior.
- `style.css`: GTK CSS styling for Waybar.
- Optional assets (images) used by that theme.

Keep theme-specific assets inside the same theme directory. Do not place live system config files here.

## Build, Test, and Development Commands
There is no build pipeline in this repo. Work is file-based and validated manually.

Useful commands:
- `ls -1`: list available themes.
- `rg --files <theme>`: inspect files inside one theme quickly.
- `omarchy-restart-waybar`: reload Waybar after applying/testing changes on a system using Omarchy.

Example local test flow:
1. Copy or link a theme into `~/.config/waybar/themes/<theme-name>`.
2. Activate it with your normal Omarchy workflow.
3. Run `omarchy-restart-waybar` and verify visuals/modules.

## Coding Style & Naming Conventions
- Use 2-space indentation in `config.jsonc` and `style.css`.
- Prefer readable module ordering and keep existing key order unless needed.
- Use GTK-compatible CSS only (Waybar does not support all web CSS features).
- Theme directories use lowercase kebab-case (example: `frost-sentinel`).
- Keep changes minimal and theme-local; avoid unrelated edits across multiple themes.

## Testing Guidelines
Testing is manual:
- Validate JSONC edits for syntax correctness before runtime.
- Confirm modules render, tooltips work, and click actions still execute.
- Check both normal and compact/narrow bar states if your theme supports them.

When changing shared patterns across themes, spot-check at least 2-3 themes.

## Commit & Pull Request Guidelines
No historical convention is available in this snapshot, so use a simple standard:
- Commit format: `type(scope): summary` (for example, `feat(miasma): refine workspace colors`).
- Keep commits focused to one theme or one cross-theme concern.

PRs should include:
- What changed and why.
- Theme directories affected.
- Screenshots/GIFs for visual changes (before/after preferred).
- Any Omarchy-specific testing notes.
