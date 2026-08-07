use aur_response::config::{load_from_dir, migrate, parse_legacy};
use std::fs;
use tempfile::tempdir;

#[test]
fn parses_documented_fish_assignments_without_executing_code() {
    let (values, warnings) = parse_legacy(
        "set -g AUR_ENABLE_CHAOS_RAT 1\nset -g AUR_PAMAC_BUILD_GLOBS '/var/tmp/pamac-build-*' '/tmp/pamac/*'\n",
    );
    assert!(warnings.is_empty());
    assert_eq!(values["AUR_ENABLE_CHAOS_RAT"], ["1"]);
    assert_eq!(values["AUR_PAMAC_BUILD_GLOBS"].len(), 2);

    let (_, warnings) = parse_legacy("set -g AUR_DEV_ROOT (command pwd)\n");
    assert_eq!(warnings.len(), 1);
}

#[test]
fn migration_is_atomic_and_preserves_source() {
    let dir = tempdir().unwrap();
    let source = dir.path().join("config.fish");
    let target = dir.path().join("config.toml");
    fs::write(
        &source,
        concat!(
            "set -g AUR_LIST_MAX_AGE_DAYS 14\n",
            "set -g AUR_ENABLE_XEACTOR 1\n",
            "set -g AUR_ENABLE_OPENCONNECT_SSO 1\n",
            "set -g AUR_BROWSH_LINUX_UTILS_URL https://example.invalid/browsh.txt\n",
        ),
    )
    .unwrap();
    migrate(&source, &target).unwrap();
    assert!(fs::read_to_string(&source).unwrap().contains("set -g"));
    let output = fs::read_to_string(target).unwrap();
    assert!(output.contains("list_max_age_days = 14"));
    assert!(output.contains("enable_xeactor = true"));
    assert!(output.contains("enable_openconnect_sso = true"));
    assert!(output.contains("browsh_linux_utils_url = \"https://example.invalid/browsh.txt\""));
}

#[test]
fn runtime_configuration_does_not_load_legacy_fish_files() {
    let dir = tempdir().unwrap();
    fs::write(
        dir.path().join("config.fish"),
        "set -g AUR_LIST_URL_EXTRA https://legacy.invalid/list\n",
    )
    .unwrap();
    let loaded = load_from_dir(dir.path()).unwrap();
    assert_eq!(loaded.config.list_url_extra, None);
}
