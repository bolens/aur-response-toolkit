use aur_response::alpm;
use aur_response::cli::{self, CommandKind};
use aur_response::model::{FailOn, ScanState};
use aur_response::report;
use aur_response::{EXIT_INVALID, VERSION};
use flate2::write::GzEncoder;
use flate2::Compression;
use std::fs;
use std::io::Write;
use std::process::Command;
use tempfile::tempdir;

#[test]
fn cli_preserves_exit_policy_variants_and_subcommands() {
    let args = [
        "--local",
        "--all-time",
        "--fail-on=none",
        "--prune-days",
        "30",
    ]
    .into_iter()
    .map(str::to_owned)
    .collect::<Vec<_>>();
    let mut command = vec!["scan".into(), "packages".into(), "chaos-rat".into()];
    command.extend(args);
    let parsed = cli::parse("aur-response", &command).unwrap();
    assert_eq!(parsed.kind, CommandKind::Package("chaos-rat".into()));
    assert!(parsed.options.local && parsed.options.all_time);
    assert_eq!(parsed.options.fail_on, FailOn::None);
    assert_eq!(parsed.options.prune_days, 30);

    let err = cli::parse("aur-response", &["--bogus".into()])
        .err()
        .unwrap();
    assert_eq!(err.0, EXIT_INVALID);
}

#[test]
fn every_native_subcommand_routes_without_legacy_executables() {
    let cases = [
        (
            vec!["scan", "packages", "atomic-arch"],
            CommandKind::Package("atomic-arch".into()),
        ),
        (
            vec!["scan", "timeline", "xeactor"],
            CommandKind::Timeline("xeactor".into()),
        ),
        (vec!["scan", "aur-window"], CommandKind::AurWindow),
        (
            vec!["scan", "malware-artifacts"],
            CommandKind::MalwareArtifacts,
        ),
        (
            vec!["scan", "similar-heuristics"],
            CommandKind::SimilarHeuristics,
        ),
        (vec!["scan", "hardening"], CommandKind::Hardening),
        (vec!["check", "list-freshness"], CommandKind::ListFreshness),
        (vec!["audit"], CommandKind::Audit),
        (vec!["recovery", "rotate-hints"], CommandKind::RotateHints),
        (
            vec!["recovery", "apply-hardening"],
            CommandKind::ApplyHardening,
        ),
        (
            vec!["recovery", "remove-packages"],
            CommandKind::RemovePackages,
        ),
        (vec!["recovery", "scrub-history"], CommandKind::ScrubHistory),
        (vec!["config", "migrate"], CommandKind::ConfigMigrate),
    ];
    for (args, expected) in cases {
        let args = args.into_iter().map(str::to_owned).collect::<Vec<_>>();
        assert_eq!(cli::parse("aur-response", &args).unwrap().kind, expected);
    }
    let invalid = ["scan", "packages", "unknown"]
        .into_iter()
        .map(str::to_owned)
        .collect::<Vec<_>>();
    assert_eq!(
        cli::parse("aur-response", &invalid).unwrap_err().0,
        EXIT_INVALID
    );
}

#[test]
fn json_contract_has_stable_fields_and_finding_arrays() {
    let dir = tempdir().unwrap();
    let list = dir.path().join("atomic.txt");
    fs::write(&list, "beef\n").unwrap();
    let mut state = ScanState::default();
    state.counters.atomic_arch_installed = 1;
    state.finding("atomic_arch_installed", "beef");
    let path = report::write_summary(dir.path(), &state, 1, &list, &list).unwrap();
    let json: serde_json::Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
    assert_eq!(json["version"], VERSION);
    assert_eq!(json["exit_code"], 1);
    assert_eq!(json["severity"], "critical");
    assert_eq!(json["atomic_arch_installed"], 1);
    assert_eq!(json["findings"]["atomic_arch_installed"][0], "beef");
    assert_eq!(json["list_sha256"].as_str().unwrap().len(), 64);
    assert_eq!(report::sha256(&dir.path().join("missing.txt")), None);
}

#[test]
fn reads_plain_gzip_xz_zstd_and_bzip2_pacman_logs() {
    let fixture = "[2026-06-10T12:00:00-0600] [ALPM] installed beef (1-1)\n";
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("pacman.log"), fixture).unwrap();

    let mut gzip = GzEncoder::new(Vec::new(), Compression::default());
    gzip.write_all(fixture.as_bytes()).unwrap();
    fs::write(dir.path().join("pacman.log.1.gz"), gzip.finish().unwrap()).unwrap();

    for (program, extension, arguments) in [
        ("xz", "xz", &["-zc"][..]),
        ("zstd", "zst", &["-q", "-c"][..]),
        ("bzip2", "bz2", &["-c"][..]),
    ] {
        let source = dir.path().join(format!("{program}.log"));
        fs::write(&source, fixture).unwrap();
        let output = Command::new(program)
            .args(arguments)
            .arg(&source)
            .output()
            .unwrap_or_else(|error| panic!("{program} is required for this test: {error}"));
        assert!(output.status.success(), "{program} compression failed");
        fs::write(
            dir.path().join(format!("pacman.log.2.{extension}")),
            output.stdout,
        )
        .unwrap();
        fs::remove_file(source).unwrap();
    }

    let events =
        alpm::events(dir.path(), aur_response::model::Campaign::AtomicArch, false).unwrap();
    assert_eq!(events.len(), 5);
    assert!(events.iter().all(|event| event.package == "beef"));
}

#[test]
fn compressed_log_errors_are_reported_instead_of_truncated() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("pacman.log.1.xz"), "not an xz stream").unwrap();
    let error =
        alpm::events(dir.path(), aur_response::model::Campaign::AtomicArch, false).unwrap_err();
    assert_eq!(error.kind(), std::io::ErrorKind::InvalidData);
}
