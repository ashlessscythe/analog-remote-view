# Mod Portal description (copy-paste)

Paste everything **below the horizontal rule** into the Factorio Mod Portal **Description** field.

The Mod Portal accepts a limited markdown subset. Screenshots live on the `public` branch under `media/` (excluded from the release ZIP).

---

# Remote View CRT

> **Old-school surveillance terminal overlays for Factorio Remote View.**

Turns Remote View into a CRT / VHS / tactical feed using **GUI overlays only**. Your factory stays visible and usable underneath.

Built for **Factorio 2.1**. Space Age is supported but not required. Nothing about recipes, combat, or progression is changed.

**Important:** This mod simulates display effects with Factorio GUI sprites and text. It does **not** modify the game's rendering pipeline or apply real shaders.

---

## Features

- Overlay while in Remote View (optional global mode)
- Presets: Classic CRT, Terminal Green, VHS, Military, Sci-Fi, Mono Green, Mono Amber, Clean/Off
- Scanlines, vignette, phosphor grid, noise, flicker
- Configurable simulated screen tearing / signal glitches
- Themed HUD: surface, coordinates, camera id, signal, timestamps
- Per-player settings (multiplayer-safe)
- Open settings with **Ctrl+Shift+C** or the shortcut button

---

## How to use

1. Enter **Remote View** (default **TAB** / Toggle map).
2. Press **Ctrl+Shift+C** (or the CRT shortcut) to pick a preset and tune effects.
3. Exit Remote View — the overlay disappears (unless you enabled Global overlay).

---

## Settings

Per player, in **Settings → Mod settings**:

- Enable Remote View CRT
- Default preset
- Remote View only
- Master intensity
- Debug mode

Fine controls live in the in-game settings window.

---

## Compatibility

- Factorio **2.1**
- Vanilla and **Space Age**
- No extra dependencies
- Compatible with Remote View Favorites and similar Remote View mods

---

## Limitations

- Cosmetic GUI overlay, not true CRT distortion
- Draws above the vanilla HUD
- Timestamp "real" mode uses playtime (Factorio has no OS calendar API)

---

## Links

- [GitHub](https://github.com/ashlessscythe/analog-remote-view)
