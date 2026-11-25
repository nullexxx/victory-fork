use std::path::Path;
use std::process::Command;

#[test]
fn translate_rejects_zero_workers() {
    let input = Path::new(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml");
    for extra_args in [&[][..], &["--cache"][..]] {
        let output = Command::new(env!("CARGO_BIN_EXE_victory"))
            .arg("translate")
            .arg(&input)
            .args(["--jobs", "0"])
            .args(extra_args)
            .output()
            .expect("run victory translate");

        let stderr = String::from_utf8_lossy(&output.stderr);
        assert_eq!(output.status.code(), Some(2), "{extra_args:?}: {stderr}");
        assert!(stderr.contains("--jobs"), "{extra_args:?}: {stderr}");
    }
}

/// A container with no parts: found and counted by the census, with no
/// program in it to translate.
fn empty_container() -> Vec<u8> {
    let mut c = b"DXBC".to_vec();
    c.extend([0; 16]); // digest
    c.extend(1u16.to_le_bytes());
    c.extend(0u16.to_le_bytes());
    c.extend(32u32.to_le_bytes()); // total size
    c.extend(0u32.to_le_bytes()); // parts
    c
}

/// A fresh folder holding one empty container (no dev-dependency for a
/// temporary folder: the app has none).
fn input(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("victory-translate-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("shaders.bin"), empty_container()).unwrap();
    dir
}

/// The census needs no host: it runs on every platform, `--list` included.
#[test]
fn translate_census_runs_on_a_synthetic_input() {
    let dir = input("census");
    let output = Command::new(env!("CARGO_BIN_EXE_victory"))
        .arg("translate")
        .arg(&dir)
        .arg("--list")
        .output()
        .expect("run victory translate");
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(output.status.success(), "{output:?}");
    assert!(
        stdout.contains("containers   1 (0 duplicates skipped)"),
        "{stdout}"
    );
    assert!(
        stdout.contains("programs     0 translated of 0"),
        "{stdout}"
    );
    let _ = std::fs::remove_dir_all(&dir);
}

/// Off Windows the checks against the host and the warm-up are refused,
/// and say why.
#[cfg(not(windows))]
#[test]
fn translate_refuses_only_what_needs_windows() {
    let dir = input("refused");
    for args in [&["--validate"][..], &["--pipelines"][..], &["--cache"][..]] {
        let output = Command::new(env!("CARGO_BIN_EXE_victory"))
            .arg("translate")
            .arg(&dir)
            .args(args)
            .output()
            .expect("run victory translate");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(!output.status.success(), "{args:?} succeeded");
        assert!(stderr.contains("need"), "{args:?}: {stderr}");
    }
    let _ = std::fs::remove_dir_all(&dir);
}
