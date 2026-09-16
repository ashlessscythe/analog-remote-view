//! macOS ScreenCaptureKit discovery and window capture streaming.

use std::sync::{Arc, Mutex};

use analog_remote_view_core::{
    CaptureBackendKind, FactorioTarget, Frame, PixelFormat as CorePixelFormat,
};
use screencapturekit::cm::CMSampleBufferExt;
use screencapturekit::cv::CVPixelBufferLockFlags;
use screencapturekit::prelude::*;
use screencapturekit::shareable_content::{ContentSnapshot, DisplaySnapshot, WindowSnapshot};
use tracing::{debug, warn};

use crate::discover::{find_factorio_processes, is_factorio_process_name};
use crate::{CaptureBackend, FindError};

/// Shared slot holding only the newest completed frame.
type LatestFrame = Arc<Mutex<Option<Frame>>>;

pub struct MacOsCapture {
    stream: Option<SCStream>,
    latest: LatestFrame,
}

impl MacOsCapture {
    pub fn new() -> Self {
        Self {
            stream: None,
            latest: Arc::new(Mutex::new(None)),
        }
    }
}

impl Default for MacOsCapture {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for MacOsCapture {
    fn drop(&mut self) {
        self.stop_capture();
    }
}

impl CaptureBackend for MacOsCapture {
    fn kind(&self) -> CaptureBackendKind {
        CaptureBackendKind::MacOsScreenCaptureKit
    }

    fn find_factorio(&self) -> Result<FactorioTarget, FindError> {
        match find_via_screencapturekit() {
            Ok(target) => Ok(target),
            Err(FindError::PermissionRequired(msg)) => Err(FindError::PermissionRequired(msg)),
            Err(err) => {
                warn!(
                    error = %err,
                    "ScreenCaptureKit Factorio lookup failed; falling back to process list"
                );
                find_factorio_processes()
                    .into_iter()
                    .next()
                    .ok_or(FindError::NotFound)
            }
        }
    }

    fn start_capture(&mut self, target: &FactorioTarget) -> Result<(), FindError> {
        self.stop_capture();
        init_core_graphics();

        let content = SCShareableContent::get().map_err(|e| classify_sck_error(&e))?;
        let snapshot = content
            .snapshot()
            .ok_or_else(|| FindError::Backend("ScreenCaptureKit snapshot unavailable".into()))?;

        let chosen_id = resolve_window_id(target, &snapshot)?;
        let live_windows = content.windows();
        let window = live_windows
            .iter()
            .find(|w| u64::from(w.window_id()) == chosen_id)
            .ok_or_else(|| {
                FindError::Backend(format!(
                    "Factorio window {chosen_id} vanished before capture started"
                ))
            })?;

        let (out_w, out_h) = capture_dimensions(window, &snapshot.displays);
        debug!(
            window_id = chosen_id,
            width = out_w,
            height = out_h,
            "starting ScreenCaptureKit window stream"
        );

        let filter = SCContentFilter::create().with_window(window).build();
        let config = SCStreamConfiguration::new()
            .with_width(out_w)
            .with_height(out_h)
            .with_pixel_format(PixelFormat::BGRA)
            .with_shows_cursor(false)
            .with_queue_depth(3);

        // Clear any leftover frame from a previous session.
        if let Ok(mut slot) = self.latest.lock() {
            *slot = None;
        }

        let handler = FrameHandler {
            latest: Arc::clone(&self.latest),
        };
        let mut stream = SCStream::new(&filter, &config);
        stream.add_output_handler(handler, SCStreamOutputType::Screen);
        stream.start_capture().map_err(|e| classify_sck_error(&e))?;

        self.stream = Some(stream);
        Ok(())
    }

    fn next_frame(&mut self) -> Result<Option<Frame>, FindError> {
        let mut slot = self
            .latest
            .lock()
            .map_err(|_| FindError::Backend("frame slot poisoned".into()))?;
        Ok(slot.take())
    }

    fn stop_capture(&mut self) {
        if let Some(stream) = self.stream.take() {
            if let Err(err) = stream.stop_capture() {
                warn!(error = %err, "failed to stop ScreenCaptureKit stream cleanly");
            }
        }
        if let Ok(mut slot) = self.latest.lock() {
            *slot = None;
        }
    }
}

struct FrameHandler {
    latest: LatestFrame,
}

impl SCStreamOutputTrait for FrameHandler {
    fn did_output_sample_buffer(&self, sample: CMSampleBuffer, of_type: SCStreamOutputType) {
        if !matches!(of_type, SCStreamOutputType::Screen) {
            return;
        }
        let Some(pixel_buffer) = sample.pixel_buffer() else {
            return;
        };
        let Ok(guard) = pixel_buffer.lock(CVPixelBufferLockFlags::READ_ONLY) else {
            return;
        };
        let width = guard.width() as u32;
        let height = guard.height() as u32;
        let stride = guard.bytes_per_row();
        let Some(slice) = (unsafe { guard.as_slice() }) else {
            return;
        };

        let frame = Frame {
            width,
            height,
            stride,
            format: CorePixelFormat::Bgra8,
            pixels: slice.to_vec(),
        };

        if let Ok(mut slot) = self.latest.lock() {
            *slot = Some(frame);
        }
    }
}

fn init_core_graphics() {
    extern "C" {
        fn sc_initialize_core_graphics();
    }
    unsafe { sc_initialize_core_graphics() };
}

fn looks_like_factorio_app(name: &str, bundle_id: &str) -> bool {
    let name_l = name.to_ascii_lowercase();
    let bundle_l = bundle_id.to_ascii_lowercase();
    name_l.contains("factorio") || bundle_l.contains("factorio") || is_factorio_process_name(name)
}

fn find_via_screencapturekit() -> Result<FactorioTarget, FindError> {
    let content = SCShareableContent::get().map_err(|e| classify_sck_error(&e))?;
    let ContentSnapshot {
        applications,
        windows,
        ..
    } = content
        .snapshot()
        .ok_or_else(|| FindError::Backend("ScreenCaptureKit snapshot unavailable".into()))?;

    // Prefer an on-screen Factorio window with a live title.
    for window in &windows {
        let Some(app_idx) = window.owning_app_index else {
            continue;
        };
        let Some(app) = applications.get(app_idx) else {
            continue;
        };
        if !looks_like_factorio_app(&app.application_name, &app.bundle_identifier) {
            continue;
        }
        if !window.is_on_screen {
            debug!(
                window_id = window.window_id,
                "skipping off-screen Factorio window"
            );
            continue;
        }

        return Ok(FactorioTarget {
            process_id: app.process_id as u32,
            process_name: app.application_name.clone(),
            window_title: window.title.clone(),
            window_id: Some(u64::from(window.window_id)),
            bundle_id: Some(app.bundle_identifier.clone()),
        });
    }

    // Fall back to the Factorio application entry even if no titled window matched.
    if let Some(app) = applications
        .iter()
        .find(|a| looks_like_factorio_app(&a.application_name, &a.bundle_identifier))
    {
        return Ok(FactorioTarget {
            process_id: app.process_id as u32,
            process_name: app.application_name.clone(),
            window_title: None,
            window_id: None,
            bundle_id: Some(app.bundle_identifier.clone()),
        });
    }

    Err(FindError::NotFound)
}

/// Prefer the discovered `window_id`; otherwise find an on-screen Factorio window.
fn resolve_window_id(
    target: &FactorioTarget,
    snapshot: &ContentSnapshot,
) -> Result<u64, FindError> {
    if let Some(id) = target.window_id {
        if snapshot
            .windows
            .iter()
            .any(|w| u64::from(w.window_id) == id)
        {
            return Ok(id);
        }
        warn!(
            window_id = id,
            "stored Factorio window_id missing from snapshot; re-resolving"
        );
    }

    pick_factorio_window(target, &snapshot.applications, &snapshot.windows)
        .map(|w| u64::from(w.window_id))
        .ok_or_else(|| {
            FindError::Backend(
                "no on-screen Factorio window available for capture (is the game visible?)".into(),
            )
        })
}

fn pick_factorio_window<'a>(
    target: &FactorioTarget,
    applications: &[screencapturekit::shareable_content::ApplicationSnapshot],
    windows: &'a [WindowSnapshot],
) -> Option<&'a WindowSnapshot> {
    let mut best: Option<&WindowSnapshot> = None;
    for window in windows {
        let Some(app_idx) = window.owning_app_index else {
            continue;
        };
        let Some(app) = applications.get(app_idx) else {
            continue;
        };

        let pid_match = app.process_id as u32 == target.process_id;
        let bundle_match = target
            .bundle_id
            .as_ref()
            .map(|b| b.eq_ignore_ascii_case(&app.bundle_identifier))
            .unwrap_or(false);
        let name_match = looks_like_factorio_app(&app.application_name, &app.bundle_identifier);

        if !(pid_match || bundle_match || name_match) {
            continue;
        }
        if !window.is_on_screen {
            continue;
        }
        if window.frame.size.width < 64.0 || window.frame.size.height < 64.0 {
            continue;
        }

        // Prefer larger windows (main game view over tiny utility panels).
        let area = window.frame.size.width * window.frame.size.height;
        let better = match best {
            None => true,
            Some(prev) => area > prev.frame.size.width * prev.frame.size.height,
        };
        if better {
            best = Some(window);
        }
    }
    best
}

fn capture_dimensions(window: &SCWindow, displays: &[DisplaySnapshot]) -> (u32, u32) {
    let frame = window.frame();
    let scale = display_scale(displays).max(1.0);
    let width = ((frame.size.width * scale).round() as u32).max(1);
    let height = ((frame.size.height * scale).round() as u32).max(1);
    (width, height)
}

fn display_scale(displays: &[DisplaySnapshot]) -> f64 {
    displays
        .iter()
        .find(|d| d.frame.size.width > 0.0)
        .map(|d| f64::from(d.width) / d.frame.size.width)
        .filter(|s| s.is_finite() && *s > 0.0)
        .unwrap_or(1.0)
}

fn classify_sck_error(err: &impl std::fmt::Display) -> FindError {
    let text = err.to_string();
    let lower = text.to_ascii_lowercase();
    if lower.contains("permission")
        || lower.contains("not authorized")
        || lower.contains("denied")
        || lower.contains("tcc")
    {
        FindError::PermissionRequired(format!(
            "{text}. Grant Screen Recording permission to this terminal/app in \
             System Settings → Privacy & Security → Screen Recording, then relaunch."
        ))
    } else {
        FindError::Backend(text)
    }
}
