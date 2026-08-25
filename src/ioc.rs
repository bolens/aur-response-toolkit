use crate::inspection::{self, Bounded};
use regex::Regex;
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

pub const IOC_REGISTRY_VERSION: &str = "2026-08-24.1";
pub const MALWARE_HASHES: &[&str] = &[
    "6144d433f8a0316869877b5f834c801251bbb936e5f1577c5680878c7443c98b",
    "7883bda1ff15425f2dbe622c45a3ae105ddfa6175009bbf0b0cad9bf5c79b316",
    "47893d9badc38c54b71321263ce8178c1abb10396e0aadf9793e61ec8829e204",
    "2d25d2ea313767fae5808164224cf6ad610ab09546d1e5a6f033eedbfd98a281",
    "e73a35b3e75e94746428d1a207703d6335933deadee7d1d9c9d0328df7b9df77",
    "06c857c8ca798d50c765b4de39e6c4f272ecb57bc8316a8ed4c0fdf02fb59502",
    "5bf2071c83872fc9b3fb3f664f4d3a376c811fc01e1656afc62632b2fac4f646",
];
pub const IOC_PROVENANCE: &[&str] = &[
    "arch-aur-general:FPT525XVV2DL2P437KPHTADV3KJINORN",
    "gist-ysf:502a324ff301d0c738e8ae011272fd59",
    "gist-ysf:57850cdee152da066ac51c07a452e883",
    "gist-firstp1ck:3ea306410a8894d28806a1629c67e825",
];
const PACKAGES: &[&str] = &[
    "atomic-lockfile",
    "js-digest",
    "lockfile-js",
    "nextfile-js",
    "crypto-javascript",
    "linux-utils",
];

#[derive(Debug, Default)]
pub struct ScanResult {
    pub hits: BTreeSet<String>,
    pub roots_scanned: u64,
    pub roots_unreadable: u64,
    pub files_skipped_oversize: u64,
    pub runtime_adapters_unavailable: u64,
}

fn inspected_text(path: &Path, result: &mut ScanResult) -> Option<String> {
    match inspection::read_text(path) {
        Ok(Bounded::Value(text)) => Some(text),
        Ok(Bounded::Oversize) => {
            result.files_skipped_oversize += 1;
            None
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => None,
        Err(_) => {
            result.roots_unreadable += 1;
            None
        }
    }
}

fn command_output(program: &str, args: &[&str]) -> Option<String> {
    if env::var_os("AUR_TEST_DISABLE_RUNTIME_ADAPTERS").is_some() {
        return None;
    }
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).into_owned())
}

fn process_is_noise(line: &str) -> bool {
    Regex::new(r"(?i)pgrep|/grep |/rg |(^|[\s/])rg\s|ripgrep|ps -eo |aur-response|scan-malware|atomic-arch-response")
        .unwrap()
        .is_match(line)
}

fn process_is_ioc(line: &str) -> bool {
    let deps = Regex::new(r"/deps(?:\s|$)").unwrap();
    PACKAGES.iter().any(|name| line.contains(name))
        || deps.is_match(line)
        || line.contains("/usr/local/bin/systemmanager")
        || (line.contains("dbus-daemon") && line.contains("torrc"))
}

fn service_is_ioc(name: &str, text: &str, persistence: &Regex) -> bool {
    let exec = text.lines().find(|line| line.starts_with("ExecStart="));
    let hidden_service = name.starts_with('.') && name.ends_with(".service");
    exec.is_some_and(|line| persistence.is_match(line))
        || (hidden_service
            && text.lines().any(|line| line == "Restart=always")
            && exec.is_some_and(|line| line.contains("/var/lib/") || line.contains("/.")))
}

pub fn runtime_iocs(home: &Path) -> ScanResult {
    let mut result = ScanResult::default();
    let processes = command_output("ps", &["-eo", "pid=,args="]);
    if processes.is_none() {
        result.runtime_adapters_unavailable += 1;
    }
    let processes = processes.unwrap_or_default();
    for line in processes.lines() {
        if process_is_noise(line) {
            continue;
        }
        if process_is_ioc(line) {
            result.hits.insert(format!("process:{line}"));
        }
    }
    let connections =
        { command_output("ss", &["-H", "-tun"]).or_else(|| command_output("netstat", &["-tun"])) };
    if connections.is_none() {
        result.runtime_adapters_unavailable += 1;
    }
    for line in connections.unwrap_or_default().lines() {
        if line.contains("temp.sh")
            || line.contains("olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion")
        {
            result.hits.insert(format!("network:{line}"));
        }
    }
    let default_cron_roots = [
        PathBuf::from("/etc/crontab"),
        PathBuf::from("/var/spool/cron"),
        PathBuf::from("/etc/cron.d"),
        PathBuf::from("/etc/cron.daily"),
        PathBuf::from("/etc/cron.hourly"),
        home.join(".config/crontab"),
    ];
    let cron_roots = env::var_os("AUR_TEST_CRON_ROOTS")
        .map(|roots| env::split_paths(&roots).collect::<Vec<_>>())
        .unwrap_or_else(|| default_cron_roots.into());
    let pattern = Regex::new(
        r"(?i)deps|/var/lib/|atomic-lockfile|js-digest|linux-utils|validator|systemmanager|\.onion",
    )
    .unwrap();
    for root in cron_roots {
        if !root.exists() {
            continue;
        }
        result.roots_scanned += 1;
        for item in WalkDir::new(root)
            .max_depth(3)
            .follow_links(false)
            .into_iter()
        {
            let entry = match item {
                Ok(entry) => entry,
                Err(_) => {
                    result.roots_unreadable += 1;
                    continue;
                }
            };
            if entry.file_type().is_file()
                && matches!(inspection::read_text(entry.path()), Ok(Bounded::Value(text)) if pattern.is_match(&text))
            {
                result
                    .hits
                    .insert(format!("cron:{}", entry.path().display()));
            } else if matches!(inspection::read_text(entry.path()), Ok(Bounded::Oversize)) {
                result.files_skipped_oversize += 1;
            }
        }
    }
    result
}

pub fn persistence_iocs(home: &Path) -> ScanResult {
    let mut result = ScanResult::default();
    let persistence = Regex::new(
        r"(?i)deps|/var/lib/|atomic-lockfile|js-digest|linux-utils|validator|systemmanager|\.onion",
    )
    .unwrap();
    if env::var_os("AUR_TEST_SKIP_LD_PRELOAD").is_none() {
        let path = Path::new("/etc/ld.so.preload");
        if inspected_text(path, &mut result).is_some_and(|text| persistence.is_match(&text)) {
            result.hits.insert(format!("ld_preload:{}", path.display()));
        }
    }
    let system_root = env::var_os("AUR_TEST_SYSTEMD_SYSTEM_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/etc/systemd/system"));
    for root in [system_root, home.join(".config/systemd/user")] {
        if !root.exists() {
            continue;
        }
        result.roots_scanned += 1;
        for item in WalkDir::new(root).max_depth(2).into_iter() {
            let entry = match item {
                Ok(entry) => entry,
                Err(_) => {
                    result.roots_unreadable += 1;
                    continue;
                }
            };
            let name = entry
                .path()
                .file_name()
                .and_then(|value| value.to_str())
                .unwrap_or_default();
            if entry.file_type().is_file()
                && entry.path().extension().and_then(|value| value.to_str()) == Some("service")
                && inspected_text(entry.path(), &mut result)
                    .is_some_and(|text| service_is_ioc(name, &text, &persistence))
            {
                result
                    .hits
                    .insert(format!("systemd:{}", entry.path().display()));
            }
        }
    }
    for path in [
        home.join(".bashrc"),
        home.join(".bash_profile"),
        home.join(".profile"),
        home.join(".zshrc"),
        home.join(".config/fish/config.fish"),
    ] {
        if inspected_text(&path, &mut result).is_some_and(|text| persistence.is_match(&text)) {
            result.hits.insert(format!("shell_rc:{}", path.display()));
        }
    }
    let autostart = home.join(".config/autostart");
    if autostart.exists() {
        result.roots_scanned += 1;
        for item in WalkDir::new(autostart).max_depth(2) {
            let entry = match item {
                Ok(entry) => entry,
                Err(_) => {
                    result.roots_unreadable += 1;
                    continue;
                }
            };
            if entry.file_type().is_file()
                && entry.path().extension().and_then(|value| value.to_str()) == Some("desktop")
                && inspected_text(entry.path(), &mut result).is_some_and(|text| {
                    text.lines()
                        .any(|line| line.starts_with("Exec=") && persistence.is_match(line))
                })
            {
                result
                    .hits
                    .insert(format!("autostart:{}", entry.path().display()));
            }
        }
    }
    for path in [
        PathBuf::from("/dev/shm/.agent.bin"),
        PathBuf::from("/tmp/.agent.bin"),
        PathBuf::from("/tmp/agent.bin"),
        PathBuf::from("/usr/local/bin/systemmanager"),
        home.join(".config/systemd/user/gh-token-monitor.service"),
        home.join(".local/bin/gh-token-monitor.sh"),
        home.join(".config/gh-token-monitor"),
    ] {
        if path.exists() {
            result
                .hits
                .insert(format!("campaign_artifact:{}", path.display()));
        }
    }
    result
}

pub fn ebpf_iocs() -> BTreeSet<String> {
    ["hidden_pids", "hidden_names", "hidden_inodes"]
        .into_iter()
        .map(|name| PathBuf::from("/sys/fs/bpf").join(name))
        .filter(|path| path.exists())
        .map(|path| path.display().to_string())
        .collect()
}

pub fn registry_sha256() -> String {
    let mut digest = Sha256::new();
    digest.update(IOC_REGISTRY_VERSION);
    for value in MALWARE_HASHES.iter().chain(IOC_PROVENANCE) {
        digest.update([0]);
        digest.update(value);
    }
    format!("{:x}", digest.finalize())
}

pub fn cache_iocs(home: &Path, quick: bool) -> ScanResult {
    let mut roots = vec![
        env::var_os("AUR_TEST_NPM_CACHE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".npm")),
        home.join(".cache/npm"),
        home.join(".bun/install/cache"),
    ];
    if !quick {
        roots.push(home.join(".local/share/npm"));
    }
    let mut result = ScanResult::default();
    for root in roots {
        if !root.exists() {
            continue;
        }
        result.roots_scanned += 1;
        for item in WalkDir::new(root)
            .max_depth(if quick { 4 } else { 8 })
            .follow_links(false)
            .into_iter()
        {
            let entry = match item {
                Ok(entry) => entry,
                Err(_) => {
                    result.roots_unreadable += 1;
                    continue;
                }
            };
            if PACKAGES
                .iter()
                .any(|package| entry.path().to_string_lossy().contains(package))
            {
                result.hits.insert(entry.path().display().to_string());
            }
            if entry.file_type().is_file() {
                match inspection::sha256(entry.path(), inspection::MAX_ARTIFACT_BYTES) {
                    Ok(Bounded::Value(hash)) if MALWARE_HASHES.contains(&hash.as_str()) => {
                        result.hits.insert(entry.path().display().to_string());
                    }
                    Ok(Bounded::Oversize) => result.files_skipped_oversize += 1,
                    _ => {}
                }
            }
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_toolkit_processes() {
        assert!(process_is_noise("1 rg atomic-lockfile"));
        assert!(!process_is_noise("22 /var/lib/deps"));
    }

    #[test]
    fn compound_runtime_rules_distinguish_disguised_tor() {
        assert!(process_is_ioc("42 dbus-daemon -f /tmp/random.torrc"));
        assert!(process_is_ioc("43 /usr/local/bin/systemmanager"));
        assert!(!process_is_ioc("1 /usr/bin/dbus-daemon --system"));
        assert!(!process_is_ioc("2 systemmanager --legitimate-name"));
    }

    #[test]
    fn hidden_service_requires_persistence_and_suspicious_exec_path() {
        let pattern = Regex::new(r"systemmanager|\.onion").unwrap();
        assert!(service_is_ioc(
            ".random.service",
            "ExecStart=/var/lib/postfix/random\nRestart=always\n",
            &pattern,
        ));
        assert!(!service_is_ioc(
            ".legitimate.service",
            "ExecStart=/usr/bin/example\nRestart=always\n",
            &pattern,
        ));
    }

    #[test]
    fn registry_contains_reviewed_validator_hashes() {
        assert!(MALWARE_HASHES
            .contains(&"e73a35b3e75e94746428d1a207703d6335933deadee7d1d9c9d0328df7b9df77"));
        assert!(MALWARE_HASHES
            .contains(&"06c857c8ca798d50c765b4de39e6c4f272ecb57bc8316a8ed4c0fdf02fb59502"));
        assert_eq!(registry_sha256().len(), 64);
    }

    #[test]
    fn cache_scan_reports_package_paths_and_oversized_files() {
        let home = tempfile::tempdir().unwrap();
        let package = home.path().join(".cache/npm/linux-utils/index.mjs");
        let oversized = home.path().join(".cache/npm/ordinary-package/blob");
        std::fs::create_dir_all(package.parent().unwrap()).unwrap();
        std::fs::create_dir_all(oversized.parent().unwrap()).unwrap();
        std::fs::write(&package, "export default true;\n").unwrap();
        std::fs::write(
            &oversized,
            vec![0_u8; inspection::MAX_ARTIFACT_BYTES as usize + 1],
        )
        .unwrap();

        let result = cache_iocs(home.path(), true);
        assert!(result
            .hits
            .iter()
            .any(|hit| hit.ends_with("linux-utils/index.mjs")));
        assert_eq!(result.files_skipped_oversize, 1);
        assert_eq!(result.roots_scanned, 1);
    }
}
