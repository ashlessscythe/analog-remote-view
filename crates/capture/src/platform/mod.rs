//! Platform-specific capture backend selection.

#[cfg(all(unix, not(target_os = "macos")))]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

use crate::CaptureBackend;

/// Concrete backend for the current OS.
#[cfg(target_os = "macos")]
pub type PlatformCapture = macos::MacOsCapture;

#[cfg(target_os = "windows")]
pub type PlatformCapture = windows::WindowsCapture;

#[cfg(all(unix, not(target_os = "macos")))]
pub type PlatformCapture = linux::LinuxCapture;

#[cfg(not(any(target_os = "macos", target_os = "windows", unix)))]
compile_error!("unsupported target OS for analog-remote-view-capture");

/// Construct the default capture backend for this platform.
pub fn create_backend() -> PlatformCapture {
    #[cfg(target_os = "macos")]
    {
        macos::MacOsCapture::new()
    }
    #[cfg(target_os = "windows")]
    {
        windows::WindowsCapture::new()
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        linux::LinuxCapture::new()
    }
}

// Ensure trait object friendliness in docs / future use.
const _: () = {
    fn _assert_backend<T: CaptureBackend>() {}
    fn _check() {
        _assert_backend::<PlatformCapture>();
    }
};
