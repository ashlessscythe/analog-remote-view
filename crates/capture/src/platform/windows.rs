//! Windows Graphics Capture discovery stub (process-based until Milestone 3).

use analog_remote_view_core::{CaptureBackendKind, FactorioTarget};

use crate::discover::find_factorio_processes;
use crate::{CaptureBackend, FindError};

pub struct WindowsCapture;

impl WindowsCapture {
    pub fn new() -> Self {
        Self
    }
}

impl Default for WindowsCapture {
    fn default() -> Self {
        Self::new()
    }
}

impl CaptureBackend for WindowsCapture {
    fn kind(&self) -> CaptureBackendKind {
        CaptureBackendKind::WindowsGraphicsCapture
    }

    fn find_factorio(&self) -> Result<FactorioTarget, FindError> {
        // Milestone 2: process discovery. Window HWND targeting arrives with
        // the `windows-capture` integration in Milestone 3.
        find_factorio_processes()
            .into_iter()
            .next()
            .ok_or(FindError::NotFound)
    }
}
