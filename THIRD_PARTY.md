# Analog Remote View — third-party notices

This project will incorporate third-party components. Required license texts
and attribution will be expanded as dependencies are integrated into shipping
builds. Current planned / used components:

## In-tree Factorio mod

- **analog-remote-view** (Factorio Lua mod) — MIT (see root `LICENSE`)

## Companion application (Rust)

Planned or already referenced dependencies (inspect each crate’s `Cargo.toml`
and upstream LICENSE files before redistribution):

| Component | Role | License (upstream) |
|-----------|------|--------------------|
| [ntsc-rs](https://github.com/ntsc-rs/ntsc-rs) (`crates/ntscrs`, package `ntsc-rs`) | NTSC/VHS frame processing | MIT OR ISC OR Apache-2.0 |
| [screencapturekit](https://github.com/doom-fish/screencapturekit-rs) | macOS ScreenCaptureKit | MIT OR Apache-2.0 |
| [windows-capture](https://github.com/NiiightmareXD/windows-capture) | Windows Graphics Capture (Milestone 3+) | MIT |
| [wgpu](https://github.com/gfx-rs/wgpu) | GPU presentation | MIT OR Apache-2.0 |
| [winit](https://github.com/rust-windowing/winit) | Windowing | Apache-2.0 |
| [sysinfo](https://github.com/GuillaumeGomez/sysinfo) | Process discovery | MIT |

**Do not** depend on `ntsc-rs-gui` (GPL-3.0) for the companion app.

When vendoring or modifying upstream sources, retain their license/notice files
alongside the vendored tree.
