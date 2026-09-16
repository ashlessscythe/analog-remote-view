# Analog Remote View

Cross-platform companion application + Factorio mod that processes **Remote View**
through real [ntsc-rs](https://github.com/ntsc-rs/ntsc-rs) NTSC/VHS processing.

> **Status:** early scaffolding (Milestone 3). The Factorio mod still ships its
> legacy GUI CRT overlay under `factorio-mod/`. The Rust companion app discovers
> a running Factorio window and streams it via ScreenCaptureKit on macOS;
> wgpu display and ntsc-rs integration are next.

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
    presentation/            # winit/wgpu overlay (stub)
    remote-state/            # Remote View state abstraction
  factorio-mod/              # Factorio 2.1 mod (current GUI overlay)
  scripts/                   # Mod Portal packaging helpers
  THIRD_PARTY.md
```

## Companion app (Milestone 3)

Requires a recent stable Rust toolchain.

Local CI mirror (fmt, clippy, tests, build, `--once` smoke):

```bash
./scripts/ci-check.sh
```

```bash
cargo build --workspace
cargo run -p analog-remote-view
```

Expected output shape (macOS, Factorio running):

```text
Analog Remote View companion
Milestone 3: Factorio window capture

Capture backend: macOS ScreenCaptureKit
Finding Factorio...
Factorio found.
Capture target: pid=… name=… window_id=…
Starting capture...
Capturing Factorio window… (Ctrl+C to stop)
Wrote preview: analog-remote-view-preview.png (…x…)
capture: frames=… size=…x… ~… fps
```

The first captured frame is written to `analog-remote-view-preview.png` in the
working directory so you can confirm it is the Factorio window.

If Factorio is not running, the app reports that clearly. Use `--once` to exit
successfully when Factorio is absent (CI smoke), or to capture briefly and exit
when it is present:

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
- This cloud/Linux environment cannot runtime-test ScreenCaptureKit; validate on
  a Mac with Factorio running and visible (not fully minimized).

### Platforms

| Platform | Capture | Discovery |
|----------|---------|-----------|
| macOS | ScreenCaptureKit window stream (Milestone 3) | SCK window/app list + process fallback |
| Windows | planned: Windows Graphics Capture | Process name via `sysinfo` |
| Linux | planned: PipeWire / X11 | Process name via `sysinfo` |

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
4. Display frames with wgpu
5. Remote View marker detection
6. Show presentation only in Remote View
7. Integrate real ntsc-rs (~854×480 intermediate)
8. Configuration / presets
9. Performance instrumentation
10. Packaging / distribution

## License

MIT — see [`LICENSE`](LICENSE). Third-party notices: [`THIRD_PARTY.md`](THIRD_PARTY.md).
