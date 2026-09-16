//! Analog Remote View companion application entry point.
//!
//! Milestone 1–2: start up, select the platform capture backend, and find
//! Factorio. Capture / display / ntsc-rs arrive in later milestones.

use analog_remote_view_capture::{create_backend, CaptureBackend, FindError};
use analog_remote_view_core::CaptureBackendKind;
use tracing::{error, info, warn};

fn main() {
    init_logging();

    let once = std::env::args().any(|a| a == "--once");
    let code = match run(once) {
        Ok(()) => 0,
        Err(err) => {
            error!("{err:#}");
            1
        }
    };
    std::process::exit(code);
}

fn init_logging() {
    let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));
    tracing_subscriber::fmt()
        .with_env_filter(env_filter)
        .with_target(false)
        .init();
}

fn run(once: bool) -> anyhow::Result<()> {
    println!("Analog Remote View companion");
    println!("Milestones 1–2: workspace build + Factorio discovery");
    println!();

    let backend = create_backend();
    let kind = backend.kind();
    println!("Capture backend: {}", kind.display_name());

    println!("Finding Factorio...");
    match backend.find_factorio() {
        Ok(target) => {
            println!("Factorio found.");
            println!("Capture target: {}", target.summary());
            info!(target = %target.summary(), "Factorio discovery succeeded");
            if matches!(kind, CaptureBackendKind::MacOsScreenCaptureKit) {
                println!("Next: Milestone 3 will start ScreenCaptureKit window capture.");
            } else {
                println!(
                    "Note: window capture streaming is not wired yet on this platform \
                     (process discovery only for Milestone 2)."
                );
            }
            println!("Starting capture... (not implemented yet — Milestone 3)");
        }
        Err(FindError::NotFound) => {
            println!("Factorio not found.");
            println!(
                "Start Factorio, then re-run. On macOS, ensure Screen Recording \
                 permission is granted if window listing is required."
            );
            warn!("Factorio not found");
            if once {
                // CI / smoke runs expect a clean exit when Factorio is absent.
                return Ok(());
            }
            return Err(anyhow::anyhow!("Factorio was not found"));
        }
        Err(FindError::PermissionRequired(msg)) => {
            println!("Screen Recording permission required.");
            println!("{msg}");
            return Err(anyhow::anyhow!(msg));
        }
        Err(err) => {
            println!("Discovery failed: {err}");
            return Err(err.into());
        }
    }

    Ok(())
}
