//! One tracing setup for every binary.
//!
//! Filter with `VICTORY_LOG` (falls back to `RUST_LOG`), e.g.
//! `VICTORY_LOG=victory_loader=trace,info`. Debug and trace output exist
//! only in builds with the `diagnostics` feature; a plain release build
//! logs info and above whatever the filter asks for.
//!
//! `VICTORY_LOG_FILE=<path>` writes the log to that file (appended) instead
//! of stderr: under Wine or Proton a program started by Steam has no
//! terminal, and its stderr goes nowhere. A Linux path works there as
//! `Z:\home\...`. An empty value is ignored. A path inside a VIctory
//! source tree is refused ([`crate::ensure_outside_repo`]: a log names the
//! title's files), and so is one that cannot be opened: the log then goes
//! to stderr, after a line there saying why.

use tracing_subscriber::EnvFilter;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// The most verbose level this build can log.
const CAP: LevelFilter = if cfg!(feature = "diagnostics") {
    LevelFilter::TRACE
} else {
    LevelFilter::INFO
};

/// The file `VICTORY_LOG_FILE` names, opened to append: `Ok(None)` for an
/// empty value, an error for a path inside a source tree or one that does
/// not open.
fn log_file(path: &std::path::Path) -> Result<Option<std::fs::File>, String> {
    if path.as_os_str().is_empty() {
        return Ok(None);
    }
    crate::ensure_outside_repo(path).map_err(|e| e.to_string())?;
    std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .map(Some)
        .map_err(|e| e.to_string())
}

pub fn init(default_level: &str) {
    let filter = std::env::var("VICTORY_LOG")
        .or_else(|_| std::env::var("RUST_LOG"))
        .ok()
        .and_then(|v| EnvFilter::try_new(v).ok())
        .unwrap_or_else(|| EnvFilter::new(default_level));
    let file = std::env::var_os("VICTORY_LOG_FILE").and_then(|path| {
        log_file(std::path::Path::new(&path))
            .map_err(|e| eprintln!("VICTORY_LOG_FILE {}: {e}; logging to stderr", path.to_string_lossy()))
            .ok()
            .flatten()
    });
    let registry = tracing_subscriber::registry().with(CAP).with(filter);
    let _ = match file {
        Some(file) => registry
            .with(
                tracing_subscriber::fmt::layer()
                    .with_target(true)
                    .with_ansi(false)
                    .with_writer(std::sync::Mutex::new(file)),
            )
            .try_init(),
        None => registry
            .with(
                tracing_subscriber::fmt::layer()
                    .with_target(true)
                    .with_writer(std::io::stderr),
            )
            .try_init(),
    };
}

#[cfg(test)]
mod tests {
    use super::log_file;
    use std::io::Write;

    #[test]
    fn empty_value_is_ignored() {
        assert!(matches!(log_file(std::path::Path::new("")), Ok(None)));
    }

    #[test]
    fn appends_outside_a_source_tree() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("victory.log");
        for line in ["one\n", "two\n"] {
            let mut f = log_file(&path).unwrap().unwrap();
            f.write_all(line.as_bytes()).unwrap();
        }
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "one\ntwo\n");
    }

    #[test]
    fn refused_inside_a_source_tree() {
        let tmp = tempfile::tempdir().unwrap();
        std::fs::write(tmp.path().join(crate::policy::ROOT_MARKER), "").unwrap();
        let path = tmp.path().join("logs").join("victory.log");
        assert!(log_file(&path).is_err());
        assert!(!path.exists());
    }
}
