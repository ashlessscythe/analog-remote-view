//! NTSC processing adapter.
//!
//! Milestone 7 will depend on the `ntsc-rs` crate
//! (`https://github.com/ntsc-rs/ntsc-rs`, package `ntsc-rs` in `crates/ntscrs`)
//! and process downsampled RGBA frames. This stub only documents the intended
//! surface so the workspace compiles.

use analog_remote_view_core::Frame;

/// Placeholder processor. Real implementation wires `NtscEffect` + `YiqView`.
#[derive(Debug, Default)]
pub struct NtscProcessor {
    pub enabled: bool,
}

impl NtscProcessor {
    pub fn new() -> Self {
        Self { enabled: false }
    }

    /// Process a frame. Currently a no-op pass-through placeholder.
    pub fn process(&self, frame: &Frame) -> Frame {
        frame.clone()
    }
}
