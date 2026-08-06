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
        "set -g AUR_LIST_MAX_AGE_DAYS 14\nset -g AUR_ENABLE_XEACTOR 1\n",
    )
    .unwrap();
    migrate(&source, &target).unwrap();
    assert!(fs::read_to_string(&source).unwrap().contains("set -g"));
    let output = fs::read_to_string(target).unwrap();
    assert!(output.contains("list_max_age_days = 14"));
    assert!(output.contains("enable_xeactor = true"));
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
