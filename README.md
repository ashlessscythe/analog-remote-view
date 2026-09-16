# Analog Remote View

Cross-platform companion application + Factorio mod that processes **Remote View**
through real [ntsc-rs](https://github.com/ntsc-rs/ntsc-rs) NTSC/VHS processing.

> **Status:** early scaffolding (Milestone 4). The Factorio mod still ships its
> legacy GUI CRT overlay under `factorio-mod/`. The Rust companion app captures a
> Factorio window via ScreenCaptureKit on macOS and displays it in a wgpu
> companion window; Remote View gating and ntsc-rs are next.

## Architecture

```
Factorio window
    → native capture (ScreenCaptureKit / WGC / PipeWire)
    → common Frame
    → Remote View gate
    → ntsc-rs (when remote)
    → wgpu presentation
```

Normal gameplay stays unprocessed. Processing and the overlay appear only while
Remote View is active.

## Repository layout

```
analog-remote-view/
  Cargo.toml                 # Rust workspace
  crates/
    app/                     # `cargo run` binary
    core/                    # Frame types, errors, traits
    capture/                 # Platform capture + Factorio discovery
    ntsc/                    # ntsc-rs adapter (stub)
    presentation/            # winit/wgpu companion window
    remote-state/            # Remote View state abstraction
  factorio-mod/              # Factorio 2.1 mod (current GUI overlay)
  scripts/                   # Mod Portal packaging helpers
  THIRD_PARTY.md
```

## Companion app (Milestone 4)

Requires a recent stable Rust toolchain.

Local CI mirror (fmt, clippy, tests, build, `--once` smoke):

```bash
./scripts/ci-check.sh
```

```bash
cargo build --workspace
cargo run -p analog-remote-view
```

Expected interactive output (macOS, Factorio running):

```text
Analog Remote View companion
Milestone 4: capture + display

Capture backend: macOS ScreenCaptureKit
Finding Factorio...
Factorio found.
Capture target: pid=… name=… window_id=…
Starting capture...
Opening presentation window… (Esc or close window to stop)
Wrote preview: analog-remote-view-preview.png (…x…)
display: frames=… size=…x… ~… fps
```

A separate **Analog Remote View** window shows the live capture (letterboxed).
This is a companion preview — not yet a transparent overlay on Factorio.

The first captured frame is also written to `analog-remote-view-preview.png`.

If Factorio is not running, the app reports that clearly. Use `--once` for a
headless CI smoke (no window):

```bash
cargo run -p analog-remote-view -- --once
```

### macOS notes

- Primary capture path: **ScreenCaptureKit** via the `screencapturekit` crate.
- Screen Recording permission is required for window listing/capture.
  Grant it under **System Settings → Privacy & Security → Screen Recording**,
  then relaunch the terminal / app that runs `cargo run`.
- `.cargo/config.toml` adds `-Wl,-rpath,/usr/lib/swift` so the Swift concurrency
  dylib used by the ScreenCaptureKit bridge resolves at runtime. You should not
  need a manual `RUSTFLAGS` override for normal `cargo run`.
- For reliable capture (especially with Aerospace): run Factorio **windowed** in
  the **same workspace** as Cursor / the terminal that launches the companion.
- Validate on a Mac with Factorio visible (not fully minimized).

### Platforms

| Platform | Capture | Display | Discovery |
|----------|---------|---------|-----------|
| macOS | ScreenCaptureKit window stream | wgpu companion window | SCK + process fallback |
| Windows | planned: Windows Graphics Capture | planned | Process name via `sysinfo` |
| Linux | planned: PipeWire / X11 | planned | Process name via `sysinfo` |

## Factorio mod

The existing mod lives in [`factorio-mod/`](factorio-mod/). Identity:
`analog-remote-view` for Factorio 2.1.

It currently draws a **GUI sprite CRT/VHS overlay** when Remote View is active
(`player.controller_type == defines.controllers.remote`). That overlay will be
replaced by a thin Remote View signal (marker / IPC) once the companion pipeline
works. Preset vocabulary and Remote View detection remain useful design input.

### Package for Mod Portal

```bash
./scripts/package_mod.sh dist
```

See [`docs/releasing.md`](docs/releasing.md).

## Roadmap

1. Workspace builds — **done**
2. Find Factorio — **done**
3. Capture Factorio window — **done (macOS)**
4. Display frames with wgpu — **done (companion window)**
5. Remote View marker detection
6. Show presentation only in Remote View
7. Integrate real ntsc-rs (~854×480 intermediate)
8. Configuration / presets
9. Performance instrumentation
10. Packaging / distribution

## License

MIT — see [`LICENSE`](LICENSE). Third-party notices: [`THIRD_PARTY.md`](THIRD_PARTY.md).
