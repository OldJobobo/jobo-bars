# Versioning Policy

This repository uses per-theme Semantic Versioning (SemVer), independent of theme folder names.

## Scope
- Each theme directory (for example `tilebar-v1/`, `pillbar-v1/`) is versioned independently.
- Theme directory suffixes like `-v1` or `-v2` are variant labels, not release versions.

## Source Of Truth
- Every theme should include a `VERSION` file containing exactly one SemVer value: `MAJOR.MINOR.PATCH`.
- Example:

```text
0.1.0
```

## SemVer Rules
- `PATCH` (`x.y.z -> x.y.z+1`): backward-compatible fixes and polish.
  - Examples: CSS bug fix, script reliability fix, tooltip correction, spacing/visual polish that does not change expected behavior.
- `MINOR` (`x.y.z -> x.y+1.0`): backward-compatible feature additions.
  - Examples: new module, new optional behavior (such as compact mode), new script capability that does not break existing usage.
- `MAJOR` (`x.y.z -> x+1.0.0`): breaking changes.
  - Examples: removed/renamed modules users depend on, changed required script interface, layout/config behavior that requires user migration.

## Pre-1.0 Guidance
- Themes may remain in `0.y.z` while behavior is still evolving.
- During `0.x`, treat potentially disruptive changes as `MINOR` bumps.

## Changelog Standard
- Each theme should include `CHANGELOG.md`.
- Recommended structure:
  - `## Unreleased`
  - Released sections as `## X.Y.Z - YYYY-MM-DD`
- Use standard headings when applicable:
  - `Added`
  - `Changed`
  - `Fixed`
  - `Removed`

## Release Workflow (Per Theme)
1. Move completed items from `Unreleased` into a new released section with date.
2. Update the theme `VERSION` file to match the new release version.
3. Commit with a focused message (`fix(theme): ...`, `feat(theme): ...`, `feat!(theme): ...`).
4. Create a per-theme tag to avoid collisions across themes.

## Tag Naming
- Use `<theme-dir>@<version>`.
- Examples:
  - `tilebar-v1@0.2.0`
  - `pillbar-v1@0.4.1`

## Optional Metadata
If desired, add a version line in each theme `README.md` for quick human visibility. The canonical value remains the `VERSION` file.
