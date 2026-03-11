# omabar-v2

A slim, Omarchy-friendly Waybar theme with centered status modules, native MPRIS, and configurable weather with alert awareness.

## Requirements

- OldJobobo custom Omarchy templates (source of `../omarchy/current/theme/colors.css`):
  https://github.com/OldJobobo/oldjobobo-custom-omarchy-templates

## Preview

![omabar-v2 preview](./preview.png)

## Features

- Dynamic palette support via `colors.css`
- Centered clock, weather, update, and media status modules
- Native Waybar `mpris` module with the theme's custom playing/paused styling
- Weather powered by Open-Meteo, with Weather.gov alert checks for active advisories
- Theme-local `weather-location.conf` so location can be set without editing the script itself
- Right-click on the theme name to load a random Omarchy theme

## Weather Setup

Edit `weather-location.conf` to set the forecast location.

The easiest option is:

```bash
location_query="Seattle, WA"
```

You can also pin exact coordinates if you want to be precise:

```bash
lat="47.6062"
lon="-122.3321"
```

If `lat` and `lon` are blank, the script will resolve `location_query` and cache the coordinates for later refreshes.

When Weather.gov reports an active alert for the configured point, the weather module switches to a red pulsing alert state and includes the alert details in the tooltip.

## Files

- `config.jsonc`: Waybar module layout and behavior
- `style.css`: Theme styling
- `weather-location.conf`: Theme-local weather location config
- `*.sh`: Theme-local helper scripts used by custom modules
- `VERSION`: Theme version
- `CHANGELOG.md`: Release notes
