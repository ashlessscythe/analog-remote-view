# Analog Remote View

Transforms Factorio **Remote View** into an old-school **VHS / CRT terminal** display using **GUI overlays only**.

> This mod uses Factorio GUI overlays to simulate CRT/VHS effects. It does **not** modify the game's underlying rendering pipeline. Real NTSC/VHS processing (e.g. ntsc-rs) cannot run inside Factorio — there is no native library or driver API for mods.

Built for **Factorio 2.1**. Space Age is supported but not required.

## Screenshots

_Place screenshots under `media/` and sync the `public` branch for Mod Portal image URLs._

## Features

- Defaults to a worn **VHS** look (warm wash, tracking snow, blinking REC OSD)
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
| Classic CRT | Soft green wash, scanlines, light rolling tear |
| Terminal Green | Green phosphor terminal HUD (original; not a copyrighted theme) |
| VHS | Tracking noise, blinking REC/CAM/timestamp, frequent rolling interference (**default**) |
| Military Terminal | Grid coords, uplink status, target brackets, occasional signal drop |
| Sci-Fi Surveillance | Cyan sensor-feed HUD, medium rolling interference |
| Monochrome Green / Amber | Strong mono washes |
| Clean / Off | Subtle bezel only (or fully quiet with border off) |

## Configuration

**Settings → Mod settings** (per player):

- Enable mod
- Default preset (VHS out of the box)
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
- Rolling tear/tracking bands use a 2-tick handler only while those bands are visible

## Limitations

- Not true framebuffer distortion or GPU post-processing
- Cannot embed ntsc-rs or any native library/driver — Factorio mods are Lua + sprites only
- Overlay draws above vanilla HUD (`player.gui.screen`); there is no API to clip it to the world viewport only
- Overlay hides while entity/inventory GUIs are open (e.g. **E**) so those stay readable
- No OS calendar date in the Factorio API (timestamp modes use playtime / in-game day / fixed string)
- Simulated tear/tracking bands are overlay sprites (inspired by ntsc-rs tracking noise / snow); they do not process or shift the world image underneath

## How to test

1. Symlink or copy this folder into Factorio `mods/` as `analog-remote-view_0.1.4` (or zip via `./scripts/package_mod.sh`).
2. Enable the mod; start a game.
3. Press **TAB** (Toggle map) to enter Remote View — VHS overlay should appear by default.
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
