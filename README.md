# Remote View CRT

Transforms Factorio **Remote View** into an old-school surveillance / CRT terminal display using **GUI overlays only**.

> This mod uses Factorio GUI overlays to simulate CRT/display effects. It does **not** modify the game's underlying rendering pipeline.

Built for **Factorio 2.1**. Space Age is supported but not required.

## Screenshots

_Place screenshots under `media/` and sync the `public` branch for Mod Portal image URLs._

## Features

- Overlay appears when you enter Remote View (optional global overlay mode)
- Eight visual presets: Classic CRT, Terminal Green, VHS, Military, Sci-Fi, Mono Green, Mono Amber, Clean/Off
- Scanlines, vignette, phosphor grid, noise, flicker
- Simulated screen tearing / signal interference (configurable intensity)
- Themed HUD readouts (surface, coordinates, camera id, signal, timestamps)
- Per-player settings with persistence and multiplayer independence
- Settings window: **Ctrl+Shift+C** or the shortcut bar button

## Presets

| Preset | Feel |
|--------|------|
| Classic CRT | Soft green wash, scanlines, light tear |
| Terminal Green | Green phosphor terminal HUD (original; not a copyrighted theme) |
| VHS | Tracking noise, REC/CAM/timestamp, higher tear |
| Military Terminal | Grid coords, uplink status, target brackets |
| Sci-Fi Surveillance | Cyan sensor-feed HUD |
| Monochrome Green / Amber | Strong mono washes |
| Clean / Off | Subtle bezel only (or fully quiet with border off) |

## Configuration

**Settings → Mod settings** (per player):

- Enable mod
- Default preset
- Remote View only (default)
- Master intensity
- Debug mode

**In-game settings** (Ctrl+Shift+C): fine-tune CRT, scanlines, vignette, noise, flicker, tearing, glitch frequency/duration, timestamp mode, HUD, global overlay.

Player choices persist in the save (`storage`) and are not synced between players.

## Compatibility

- Factorio 2.1, vanilla and Space Age
- No extra dependencies
- Uses unique `rvc_*` GUI names; does not touch other mods' GUIs
- Works alongside [Remote View Favorites](https://github.com/ashlessscythe/remote-view-favorites)

## Performance

- Overlay is built once on enter and destroyed on exit
- Scanlines/vignette are stretched sprites (not thousands of line widgets)
- Glitch/HUD updates run on a low-rate nth-tick only while overlays are active

## Limitations

- Not true framebuffer distortion or GPU post-processing
- Overlay draws above vanilla HUD (`player.gui.screen`)
- No OS calendar date in the Factorio API (timestamp modes use playtime / in-game day / fixed string)
- Simulated tear bands do not shift the world image underneath

## How to test

1. Symlink or copy this folder into Factorio `mods/` as `remote-view-crt_0.1.0` (or zip via `./scripts/package_mod.sh`).
2. Enable the mod; start a game.
3. Press **TAB** (Toggle map) to enter Remote View — overlay should appear.
4. Press **Ctrl+Shift+C** — change presets and toggles.
5. Exit Remote View — overlay should disappear (unless Global overlay is on).
6. Save/load while in Remote View; overlay should return.
7. In MP, set different presets per player.

### Recommended cases

- Enter/exit Remote View repeatedly
- Change surface while remote
- Resize window / UI scale
- Player death / disconnect
- Clean/Off and master intensity 0
- High tearing + frequent glitches (briefly)
- Debug mode on

## Development / release

See [docs/releasing.md](docs/releasing.md). Tag `vX.Y.Z` matching `info.json` to build the Mod Portal zip.

## License

MIT — see [LICENSE](LICENSE).
