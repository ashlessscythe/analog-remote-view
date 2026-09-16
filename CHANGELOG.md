# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.4] — 2026-09-15

### Changed

- Default preset is now **VHS** (old-school tape / security-terminal look)
- VHS preset retuned: warmer wash, stronger scanlines, higher noise and flicker
- VHS OSD: blinking ● REC, AUTO TRACKING, SP HI-FI tape labels
- High tearing glitches bias toward tracking snow and noise bursts (less total signal loss)
- Docs clarify GUI-only simulation; ntsc-rs cannot be embedded as a library or driver in Factorio

## [0.1.3] — 2026-09-15

### Changed

- Tear and tracking bands now roll vertically (random start edge, then travel toward the opposite edge) instead of freezing in place
- Tracking bursts stay edge-weighted and wrap in that zone, approximating VHS tracking noise with overlay sprites only
- Rolling interference defaults: VHS (high/frequent/long), Sci-Fi Surveillance (medium/occasional), Classic CRT and Military (low/occasional). Clean stays off; Terminal Green and mono stay rare.

### Fixed

- Loading a save no longer crashes (`on_load` cannot use `game`; rolling-band tick is rebound from storage)

## [0.1.2] — 2026-09-10

### Fixed

- Runtime mod settings (including default preset) now apply immediately in a loaded game
- Overlay hides while entity/inventory GUIs are open so **E** menus stay readable

### Changed

- Softened vignette and dirty-screen noise textures and preset defaults
- Reworked glitch scheduler so VHS/high tearing bursts are actually noticeable
- Stronger tear/tracking band sprites; VHS defaults to frequent tearing

## [0.1.1] — 2026-09-10

### Changed

- Mod internal name and title are now **analog-remote-view** / **Analog Remote View**
- Updated docs, locale, sprite paths, and packaging to match the new mod id

## [0.1.0] — 2026-09-10

### Added

- Initial release for Factorio 2.1
- Remote View detection with GUI overlay lifecycle
- Presets: Classic CRT, Terminal Green, VHS, Military, Sci-Fi, Mono Green, Mono Amber, Clean/Off
- Scanlines, vignette, phosphor grid, tint wash, noise, flicker
- Simulated screen tearing and signal-loss effects
- Themed HUD readouts and timestamp modes
- In-game settings window (Ctrl+Shift+C) and shortcut button
- Per-player persistence and multiplayer-safe cosmetics
- Debug mode and master intensity accessibility controls
