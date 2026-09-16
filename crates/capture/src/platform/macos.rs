//! macOS ScreenCaptureKit discovery (window / application listing).

use analog_remote_view_core::{CaptureBackendKind, FactorioTarget};
use screencapturekit::prelude::*;
use screencapturekit::shareable_content::ContentSnapshot;
use tracing::{debug, warn};

use crate::discover::{find_factorio_processes, is_factorio_process_name};
use crate::{CaptureBackend, FindError};

pub struct MacOsCapture;

impl MacOsCapture {
    pub fn new() -> Self {
        Self
    }
}

impl Default for MacOsCapture {
    fn default() -> Self {
        Self::new()
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
}

fn looks_like_factorio_app(name: &str, bundle_id: &str) -> bool {
    let name_l = name.to_ascii_lowercase();
    let bundle_l = bundle_id.to_ascii_lowercase();
    name_l.contains("factorio")
        || bundle_l.contains("factorio")
        || is_factorio_process_name(name)
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
