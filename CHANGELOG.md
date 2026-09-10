# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
