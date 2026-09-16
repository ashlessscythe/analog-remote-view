//! Linux discovery stub (process-based; PipeWire/X11 capture later).

use analog_remote_view_core::{CaptureBackendKind, FactorioTarget};

use crate::discover::find_factorio_processes;
use crate::{CaptureBackend, FindError};

pub struct LinuxCapture;

impl LinuxCapture {
    pub fn new() -> Self {
        Self
    }
}

impl Default for LinuxCapture {
    fn default() -> Self {
        Self::new()
    }
}

impl CaptureBackend for LinuxCapture {
    fn kind(&self) -> CaptureBackendKind {
        CaptureBackendKind::LinuxPipeWire
    }

    fn find_factorio(&self) -> Result<FactorioTarget, FindError> {
        // Process discovery only. PipeWire / X11 window capture is later.
        find_factorio_processes()
            .into_iter()
            .next()
            .ok_or(FindError::NotFound)
    }
}
