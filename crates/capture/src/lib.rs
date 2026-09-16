//! Cross-platform Factorio discovery and capture abstraction.
//!
//! Milestone 2 focuses on finding Factorio. Frame streaming arrives in later
//! milestones; backends are selected behind [`CaptureBackend`].

mod discover;
mod platform;

pub use discover::{find_factorio, find_factorio_processes, is_factorio_process_name};
pub use platform::{create_backend, PlatformCapture};

use analog_remote_view_core::{CaptureBackendKind, FactorioTarget, Frame};

/// Platform capture backend. Streaming methods are stubs until Milestone 3.
pub trait CaptureBackend {
    fn kind(&self) -> CaptureBackendKind;

    /// Prefer ScreenCaptureKit / WGC window listing when available; otherwise
    /// fall back to process discovery.
    fn find_factorio(&self) -> Result<FactorioTarget, FindError>;

    /// Reserved for Milestone 3+.
    fn start_capture(&mut self, _target: &FactorioTarget) -> Result<(), FindError> {
        Err(FindError::NotImplemented(
            "window capture streaming is not implemented yet (Milestone 3)".into(),
        ))
    }

    /// Reserved for Milestone 3+.
    fn next_frame(&mut self) -> Result<Option<Frame>, FindError> {
        Err(FindError::NotImplemented(
            "window capture streaming is not implemented yet (Milestone 3)".into(),
        ))
    }
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
