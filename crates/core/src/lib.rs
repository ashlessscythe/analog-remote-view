//! Shared types for the Analog Remote View companion application.

use thiserror::Error;

/// Pixel format for CPU-side frames exchanged between crates.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PixelFormat {
    /// Blue, green, red, alpha — common capture output.
    Bgra8,
    /// Red, green, blue, alpha — common upload/display format.
    Rgba8,
}

/// A single captured or processed frame in host memory.
#[derive(Debug, Clone)]
pub struct Frame {
    pub width: u32,
    pub height: u32,
    /// Bytes per row (may include padding).
    pub stride: usize,
    pub format: PixelFormat,
    pub pixels: Vec<u8>,
}

impl Frame {
    pub fn byte_len(&self) -> usize {
        self.pixels.len()
    }
}

/// High-level application / pipeline errors.
#[derive(Debug, Error)]
pub enum ArvError {
    #[error("Factorio was not found")]
    FactorioNotFound,
    #[error("capture backend unavailable: {0}")]
    CaptureUnavailable(String),
    #[error("permission required: {0}")]
    PermissionRequired(String),
    #[error("{0}")]
    Message(String),
}

/// Capture backend name shown in logs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CaptureBackendKind {
    MacOsScreenCaptureKit,
    WindowsGraphicsCapture,
    LinuxPipeWire,
    LinuxX11,
    Stub,
}

impl CaptureBackendKind {
    pub fn display_name(self) -> &'static str {
        match self {
            Self::MacOsScreenCaptureKit => "macOS ScreenCaptureKit",
            Self::WindowsGraphicsCapture => "Windows Graphics Capture",
            Self::LinuxPipeWire => "Linux PipeWire / XDG Desktop Portal",
            Self::LinuxX11 => "Linux X11",
            Self::Stub => "stub (platform capture not wired yet)",
        }
    }

    /// Backend intended for the current compile target.
    pub fn for_current_platform() -> Self {
        #[cfg(target_os = "macos")]
        {
            Self::MacOsScreenCaptureKit
        }
        #[cfg(target_os = "windows")]
        {
            Self::WindowsGraphicsCapture
        }
        #[cfg(all(unix, not(target_os = "macos")))]
        {
            // Prefer PipeWire on modern Linux; X11 path can be selected later at runtime.
            Self::LinuxPipeWire
        }
        #[cfg(not(any(target_os = "macos", target_os = "windows", unix)))]
        {
            Self::Stub
        }
    }
}

/// A discoverable Factorio process / window target.
#[derive(Debug, Clone)]
pub struct FactorioTarget {
    pub process_id: u32,
    pub process_name: String,
    pub window_title: Option<String>,
    pub window_id: Option<u64>,
    pub bundle_id: Option<String>,
}

impl FactorioTarget {
    pub fn summary(&self) -> String {
        let mut parts = vec![format!(
            "pid={} name={}",
            self.process_id, self.process_name
        )];
        if let Some(title) = &self.window_title {
            parts.push(format!("title=\"{title}\""));
        }
        if let Some(id) = self.window_id {
            parts.push(format!("window_id={id}"));
        }
        if let Some(bundle) = &self.bundle_id {
            parts.push(format!("bundle={bundle}"));
        }
        parts.join(" ")
    }
}
