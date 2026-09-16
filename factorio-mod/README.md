# Factorio mod: analog-remote-view

This directory is the Factorio 2.1 mod packaged for the Mod Portal.

Install by copying or symlinking this folder into Factorio `mods/` as
`analog-remote-view_0.1.4` (version must match `info.json`), or run:

```bash
./scripts/package_mod.sh dist
```

from the repository root.

The companion Rust application lives in `crates/` at the repo root. This mod
still provides the legacy GUI CRT overlay; it will shrink to Remote View
signaling once capture + ntsc-rs are working.
