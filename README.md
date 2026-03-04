# jobo-bars

A personal collection of Waybar themes targeted at Omarchy.

## Theme Notes

- `pillbar-v1` and `tilebar-v1` now use Omarchy's `colors.css` template (`../omarchy/current/theme/colors.css`) for dynamic palette-driven styling.

## Versioning Automation

- Shared policy: `VERSIONING.md`
- Script: `scripts/theme-version.sh`

Examples:

```bash
# default interactive menu (gum)
scripts/theme-version.sh

# single theme bump
scripts/theme-version.sh --mode patch --theme tilebar-v1
scripts/theme-version.sh --mode minor --theme pillbar-v1
scripts/theme-version.sh --mode major --theme tilebar-v1

# set specific version
scripts/theme-version.sh --mode set --set-version 1.2.3 --theme tilebar-v1

# apply to all discoverable themes
scripts/theme-version.sh --mode minor --all

# apply to a batch by glob
scripts/theme-version.sh --mode patch --batch '*-v1'

# combine selectors
scripts/theme-version.sh --mode patch --theme tilebar-v1 --theme pillbar-v1 --batch 'oma*'

# undo last transaction
scripts/theme-version.sh --mode undo

# safe preview
scripts/theme-version.sh --mode patch --all --dry-run
```
