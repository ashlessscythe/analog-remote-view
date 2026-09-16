//! Cross-platform Factorio discovery and capture abstraction.
//!
//! Milestone 3 adds macOS ScreenCaptureKit window streaming into shared
//! [`Frame`] values. Other platforms still discover Factorio only.

mod discover;
mod platform;

pub use discover::{find_factorio, find_factorio_processes, is_factorio_process_name};
pub use platform::{create_backend, PlatformCapture};

use analog_remote_view_core::{CaptureBackendKind, FactorioTarget, Frame};

/// Platform capture backend.
pub trait CaptureBackend {
    fn kind(&self) -> CaptureBackendKind;

    /// Prefer ScreenCaptureKit / WGC window listing when available; otherwise
    /// fall back to process discovery.
    fn find_factorio(&self) -> Result<FactorioTarget, FindError>;

    /// Start capturing frames from `target`.
    fn start_capture(&mut self, _target: &FactorioTarget) -> Result<(), FindError> {
        Err(FindError::NotImplemented(
            "window capture streaming is not implemented yet on this platform".into(),
        ))
    }

    /// Take the latest completed frame, if any (drops stale frames).
    fn next_frame(&mut self) -> Result<Option<Frame>, FindError> {
        Err(FindError::NotImplemented(
            "window capture streaming is not implemented yet on this platform".into(),
        ))
    }

    /// Stop an active capture session.
    fn stop_capture(&mut self) {}
}

/// Errors from discovery / capture setup.
#[derive(Debug, thiserror::Error)]
pub enum FindError {
    #[error("Factorio was not found")]
    NotFound,
    #[error("screen recording permission is required: {0}")]
    PermissionRequired(String),
    #[error("capture backend error: {0}")]
    Backend(String),
    #[error("{0}")]
    NotImplemented(String),
}
