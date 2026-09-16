//! Analog Remote View companion application entry point.
//!
//! Milestone 3: discover Factorio and stream its window via the platform
//! capture backend (ScreenCaptureKit on macOS). Display / ntsc-rs come later.

use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use analog_remote_view_capture::{create_backend, CaptureBackend, FindError};
use analog_remote_view_core::{CaptureBackendKind, Frame, PixelFormat};
use tracing::{error, info, warn};

const PREVIEW_PNG: &str = "analog-remote-view-preview.png";
const ONCE_TIMEOUT: Duration = Duration::from_secs(5);
const STATS_INTERVAL: Duration = Duration::from_secs(1);

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
    println!("Milestone 3: Factorio window capture");
    println!();

    let mut backend = create_backend();
    let kind = backend.kind();
    println!("Capture backend: {}", kind.display_name());

    println!("Finding Factorio...");
    let target = match backend.find_factorio() {
        Ok(target) => {
            println!("Factorio found.");
            println!("Capture target: {}", target.summary());
            info!(target = %target.summary(), "Factorio discovery succeeded");
            target
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
    };

    if !matches!(kind, CaptureBackendKind::MacOsScreenCaptureKit) {
        println!(
            "Note: window capture streaming is only implemented on macOS \
             ScreenCaptureKit for Milestone 3."
        );
        if once {
            return Ok(());
        }
        return Err(anyhow::anyhow!(
            "window capture is not implemented on this platform yet"
        ));
    }

    println!("Starting capture...");
    backend.start_capture(&target)?;
    println!("Capturing Factorio window… (Ctrl+C to stop)");
    if once {
        println!(
            "--once: waiting up to {}s for a frame",
            ONCE_TIMEOUT.as_secs()
        );
    }

    let running = Arc::new(AtomicBool::new(true));
    {
        let flag = Arc::clone(&running);
        ctrlc::set_handler(move || {
            flag.store(false, Ordering::SeqCst);
        })?;
    }

    let started = Instant::now();
    let mut frames_total: u64 = 0;
    let mut frames_window: u64 = 0;
    let mut last_stats = Instant::now();
    let mut last_size = (0u32, 0u32);
    let mut wrote_preview = false;

    while running.load(Ordering::SeqCst) {
        if once && started.elapsed() >= ONCE_TIMEOUT {
            break;
        }

        match backend.next_frame()? {
            Some(frame) => {
                frames_total += 1;
                frames_window += 1;
                last_size = (frame.width, frame.height);

                if !wrote_preview {
                    match write_preview_png(Path::new(PREVIEW_PNG), &frame) {
                        Ok(()) => {
                            println!(
                                "Wrote preview: {PREVIEW_PNG} ({}x{})",
                                frame.width, frame.height
                            );
                            info!(
                                path = PREVIEW_PNG,
                                width = frame.width,
                                height = frame.height,
                                "wrote first-frame preview PNG"
                            );
                            wrote_preview = true;
                        }
                        Err(err) => {
                            warn!(error = %err, "failed to write preview PNG");
                            wrote_preview = true; // avoid retry spam
                        }
                    }
                }

                if once && frames_total >= 1 && wrote_preview {
                    // Keep gathering briefly so stats are meaningful, but allow
                    // early exit after the first successful frame + PNG.
                    if started.elapsed() >= Duration::from_millis(500) {
                        break;
                    }
                }
            }
            None => {
                std::thread::sleep(Duration::from_millis(5));
            }
        }

        if last_stats.elapsed() >= STATS_INTERVAL {
            let elapsed = last_stats.elapsed().as_secs_f64().max(1e-6);
            let fps = frames_window as f64 / elapsed;
            println!(
                "capture: frames={frames_total} size={}x{} ~{fps:.1} fps",
                last_size.0, last_size.1
            );
            info!(
                frames = frames_total,
                width = last_size.0,
                height = last_size.1,
                fps = format!("{fps:.1}"),
                "capture stats"
            );
            frames_window = 0;
            last_stats = Instant::now();
        }
    }

    backend.stop_capture();

    if frames_total == 0 {
        if once {
            println!("No frames captured within timeout (Factorio may be minimized).");
            warn!("no frames captured in --once mode");
            return Ok(());
        }
        return Err(anyhow::anyhow!("no frames were captured"));
    }

    println!(
        "Stopped. Captured {frames_total} frame(s); last size {}x{}.",
        last_size.0, last_size.1
    );
    Ok(())
}

fn write_preview_png(path: &Path, frame: &Frame) -> anyhow::Result<()> {
    anyhow::ensure!(
        frame.format == PixelFormat::Bgra8,
        "expected BGRA8 preview frame, got {:?}",
        frame.format
    );
    let w = frame.width as usize;
    let h = frame.height as usize;
    let mut rgba = vec![0u8; w.checked_mul(h).and_then(|n| n.checked_mul(4)).unwrap_or(0)];
    anyhow::ensure!(!rgba.is_empty(), "empty frame");

    for y in 0..h {
        let src_row = y
            .checked_mul(frame.stride)
            .ok_or_else(|| anyhow::anyhow!("stride overflow"))?;
        let row_bytes = w
            .checked_mul(4)
            .ok_or_else(|| anyhow::anyhow!("row overflow"))?;
        anyhow::ensure!(
            src_row + row_bytes <= frame.pixels.len(),
            "frame buffer shorter than declared size"
        );
        let src = &frame.pixels[src_row..src_row + row_bytes];
        let dst_row = y * w * 4;
        for x in 0..w {
            let s = x * 4;
            let d = dst_row + s;
            // BGRA → RGBA
            rgba[d] = src[s + 2];
            rgba[d + 1] = src[s + 1];
            rgba[d + 2] = src[s];
            rgba[d + 3] = src[s + 3];
        }
    }

    image::save_buffer(
        path,
        &rgba,
        frame.width,
        frame.height,
        image::ColorType::Rgba8,
    )?;
    Ok(())
}
