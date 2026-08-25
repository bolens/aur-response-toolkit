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
fn bundled_validator_corpus_excludes_candidate_false_positives() {
    let input = include_str!("../data/lists/openconnect-sso-pkgs.txt");
    let packages = aur_response::lists::plain(input);
    assert_eq!(packages.len(), 203);
    assert!(packages.contains("openconnect-sso"));
    assert!(packages.contains("brave-origin"));
    assert!(!packages.contains("debtap-bin"));
}

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
fn cli_accepts_new_campaign_flags_and_exit_policies() {
    let parsed = cli::parse(
        "aur-response",
        &[
            "--openconnect-sso".into(),
            "--browsh-linux-utils".into(),
            "--xsnow-worm".into(),
            "--fail-on=browsh-linux-utils".into(),
        ],
    )
    .unwrap();
    assert!(parsed.options.campaigns.contains("openconnect-sso"));
    assert!(parsed.options.campaigns.contains("browsh-linux-utils"));
    assert!(parsed.options.campaigns.contains("xsnow-worm"));
    assert_eq!(parsed.options.fail_on, FailOn::BrowshLinuxUtils);

    for campaign in ["openconnect-sso", "browsh-linux-utils", "xsnow-worm"] {
        let args = ["scan", "packages", campaign]
            .into_iter()
            .map(str::to_owned)
            .collect::<Vec<_>>();
        assert_eq!(
            cli::parse("aur-response", &args).unwrap().kind,
            CommandKind::Package(campaign.into())
        );
    }
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
    let xeactor_list = dir.path().join("xeactor.txt");
    fs::write(&list, "beef\n").unwrap();
    fs::write(&xeactor_list, "acroread\n").unwrap();
    let mut state = ScanState::default();
    state.counters.atomic_arch_installed = 1;
    state.finding("atomic_arch_installed", "beef");
    let lists = [
        (
            aur_response::model::Campaign::Xeactor,
            xeactor_list.as_path(),
        ),
        (
            aur_response::model::Campaign::BrowshLinuxUtils,
            list.as_path(),
        ),
        (
            aur_response::model::Campaign::OpenconnectSso,
            list.as_path(),
        ),
        (aur_response::model::Campaign::XsnowWorm, list.as_path()),
        (aur_response::model::Campaign::ShaiHulud, list.as_path()),
        (aur_response::model::Campaign::ChaosRat, list.as_path()),
        (aur_response::model::Campaign::AtomicArch, list.as_path()),
    ];
    let path = report::write_summary(dir.path(), &state, 1, &lists).unwrap();
    let json: serde_json::Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
    assert_eq!(json["version"], VERSION);
    assert_eq!(json["exit_code"], 1);
    assert_eq!(json["severity"], "critical");
    assert_eq!(json["ioc_registry_version"], "2026-08-24.1");
    assert_eq!(json["ioc_registry_sha256"].as_str().unwrap().len(), 64);
    assert_eq!(json["openconnect_sso_list_retrieved"], "2026-08-24");
    assert_eq!(json["atomic_arch_installed"], 1);
    assert_eq!(json["findings"]["atomic_arch_installed"][0], "beef");
    assert_eq!(json["list_sha256"].as_str().unwrap().len(), 64);
    assert_eq!(
        json["xeactor_list_sha256"],
        report::sha256(&xeactor_list).unwrap()
    );
    assert_ne!(json["xeactor_list_sha256"], json["list_sha256"]);
    for key in [
        "chaos_rat_list_sha256",
        "shai_hulud_list_sha256",
        "openconnect_sso_list_sha256",
        "browsh_linux_utils_list_sha256",
        "xsnow_worm_list_sha256",
        "xeactor_list_sha256",
    ] {
        assert_eq!(json[key].as_str().unwrap().len(), 64);
    }
    assert_eq!(report::sha256(&dir.path().join("missing.txt")), None);
}

#[test]
fn json_contract_reports_campaign_provenance_and_incomplete_coverage() {
    let dir = tempdir().unwrap();
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let lists = aur_response::model::Campaign::ALL.map(|campaign| {
        (
            campaign,
            root.join("data/lists")
                .join(format!("{}-pkgs.txt", campaign.slug())),
        )
    });
    let list_refs = lists
        .iter()
        .map(|(campaign, path)| (*campaign, path.as_path()))
        .collect::<Vec<_>>();
    let mut state = ScanState::default();
    state.counters.files_skipped_oversize = 1;

    let path = report::write_summary(dir.path(), &state, 3, &list_refs).unwrap();
    let json: serde_json::Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
    assert_eq!(json["coverage_complete"], false);
    assert_eq!(json["campaigns"].as_array().unwrap().len(), 7);
    let xsnow = json["campaigns"]
        .as_array()
        .unwrap()
        .iter()
        .find(|campaign| campaign["slug"] == "xsnow-worm")
        .unwrap();
    assert_eq!(xsnow["observed_start"], "2026-08-23");
    assert_eq!(xsnow["observed_end"], "2026-08-23");
    assert_eq!(xsnow["scan_end"], "2026-08-24");
    assert_eq!(xsnow["retrieved"], "2026-08-24");
    assert_eq!(xsnow["list_sha256"], xsnow["expected_list_sha256"]);
    assert_eq!(xsnow["list_sha256"].as_str().unwrap().len(), 64);
}

#[test]
fn persisted_state_and_findings_are_deterministic_and_complete() {
    let dir = tempdir().unwrap();
    let mut state = ScanState {
        compromise: true,
        ..ScanState::default()
    };
    state.counters.runtime_iocs = 2;
    state.counters.roots_unreadable = 1;
    state.finding("runtime", "process:systemmanager");
    state.finding("artifacts", "/tmp/agent.bin");

    report::write_state(dir.path(), &state).unwrap();
    report::write_findings(dir.path(), &state.findings).unwrap();

    let persisted = fs::read_to_string(dir.path().join(".scan-state")).unwrap();
    assert!(persisted.contains("compromised=1\n"));
    assert!(persisted.contains("runtime_iocs=2\n"));
    assert!(persisted.contains("roots_unreadable=1\n"));
    let findings = fs::read_to_string(dir.path().join(".scan-findings.list")).unwrap();
    assert_eq!(
        findings,
        "artifacts\t/tmp/agent.bin\nruntime\tprocess:systemmanager\n"
    );
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
