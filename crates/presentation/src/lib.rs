//! Presentation / overlay layer.
//!
//! Milestone 4 will introduce `winit` + `wgpu` to display captured (and later
//! NTSC-processed) frames. This stub keeps the workspace compiling.

use analog_remote_view_core::Frame;

/// Placeholder presenter. Real implementation owns a borderless wgpu window.
#[derive(Debug, Default)]
pub struct Presenter {
    pub visible: bool,
}

impl Presenter {
    pub fn new() -> Self {
        Self { visible: false }
    }

    pub fn show_frame(&mut self, _frame: &Frame) {
        self.visible = true;
    }

    pub fn hide(&mut self) {
        self.visible = false;
    }
}
