//! Process-name heuristics shared across platforms.

use analog_remote_view_core::FactorioTarget;
use sysinfo::{ProcessesToUpdate, System};

use crate::FindError;

/// True when a process name looks like Factorio (Steam / standalone).
pub fn is_factorio_process_name(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    // Exact-ish matches first to avoid false positives like unrelated tools.
    lower == "factorio"
        || lower == "factorio.exe"
        || lower.starts_with("factorio ")
        || lower.contains("factorio.app")
}

/// Enumerate running Factorio processes via `sysinfo`.
pub fn find_factorio_processes() -> Vec<FactorioTarget> {
    let mut system = System::new();
    system.refresh_processes(ProcessesToUpdate::All, true);

    let mut targets = Vec::new();
    for (pid, process) in system.processes() {
        let name = process.name().to_string_lossy().into_owned();
        if !is_factorio_process_name(&name) {
            // Also check the executable path stem (macOS often reports the
            // binary name; Steam may include path components).
            let exe_match = process
                .exe()
                .and_then(|p| p.file_name())
                .map(|f| is_factorio_process_name(&f.to_string_lossy()))
                .unwrap_or(false);
            if !exe_match {
                continue;
            }
        }

        targets.push(FactorioTarget {
            process_id: pid.as_u32(),
            process_name: name,
            window_title: None,
            window_id: None,
            bundle_id: None,
        });
    }

    targets.sort_by_key(|t| t.process_id);
    targets
}

/// Pick the first Factorio process, or [`FindError::NotFound`].
pub fn find_factorio() -> Result<FactorioTarget, FindError> {
    find_factorio_processes()
        .into_iter()
        .next()
        .ok_or(FindError::NotFound)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_common_names() {
        assert!(is_factorio_process_name("factorio"));
        assert!(is_factorio_process_name("Factorio"));
        assert!(is_factorio_process_name("factorio.exe"));
        assert!(!is_factorio_process_name("factorio-helper-unrelated-tool"));
        assert!(!is_factorio_process_name("firefox"));
    }
}
