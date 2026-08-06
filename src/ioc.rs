use regex::Regex;
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

const MALWARE_HASHES: &[&str] = &[
    "6144d433f8a0316869877b5f834c801251bbb936e5f1577c5680878c7443c98b",
    "7883bda1ff15425f2dbe622c45a3ae105ddfa6175009bbf0b0cad9bf5c79b316",
    "47893d9badc38c54b71321263ce8178c1abb10396e0aadf9793e61ec8829e204",
];
const PACKAGES: &[&str] = &[
    "atomic-lockfile",
    "js-digest",
    "lockfile-js",
    "nextfile-js",
    "crypto-javascript",
];

fn command_output(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).into_owned())
        .unwrap_or_default()
}

fn process_is_noise(line: &str) -> bool {
    Regex::new(r"(?i)pgrep|/grep |/rg |(^|[\s/])rg\s|ripgrep|ps -eo |aur-response|scan-malware|atomic-arch-response")
        .unwrap()
        .is_match(line)
}

pub fn runtime_iocs(home: &Path) -> BTreeSet<String> {
    let mut hits = BTreeSet::new();
    let processes = command_output("ps", &["-eo", "pid=,args="]);
    let deps = Regex::new(r"/deps(?:\s|$)").unwrap();
    for line in processes.lines() {
        if process_is_noise(line) {
            continue;
        }
        if PACKAGES.iter().any(|name| line.contains(name)) || deps.is_match(line) {
            hits.insert(format!("process:{line}"));
        }
    }
    let connections = {
        let ss = command_output("ss", &["-H", "-tun"]);
        if ss.is_empty() {
            command_output("netstat", &["-tun"])
        } else {
            ss
        }
    };
    for line in connections.lines() {
        if line.contains("temp.sh")
            || line.contains("olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion")
        {
            hits.insert(format!("network:{line}"));
        }
    }
    let cron_roots = [
        PathBuf::from("/etc/crontab"),
        PathBuf::from("/var/spool/cron"),
        PathBuf::from("/etc/cron.d"),
        PathBuf::from("/etc/cron.daily"),
        PathBuf::from("/etc/cron.hourly"),
        home.join(".config/crontab"),
    ];
    let pattern = Regex::new(r"(?i)deps|/var/lib/|atomic-lockfile|js-digest").unwrap();
    for root in cron_roots {
        for entry in WalkDir::new(root)
            .max_depth(3)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
        {
            if entry.file_type().is_file()
                && fs::read_to_string(entry.path()).is_ok_and(|text| pattern.is_match(&text))
            {
                hits.insert(format!("cron:{}", entry.path().display()));
            }
        }
    }
    hits
}

pub fn persistence_iocs(home: &Path) -> BTreeSet<String> {
    let mut hits = BTreeSet::new();
    let persistence = Regex::new(r"(?i)deps|/var/lib/|atomic-lockfile|js-digest").unwrap();
    if env::var_os("AUR_TEST_SKIP_LD_PRELOAD").is_none() {
        let path = Path::new("/etc/ld.so.preload");
        if fs::read_to_string(path).is_ok_and(|text| persistence.is_match(&text)) {
            hits.insert(format!("ld_preload:{}", path.display()));
        }
    }
    let system_root = env::var_os("AUR_TEST_SYSTEMD_SYSTEM_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/etc/systemd/system"));
    for root in [system_root, home.join(".config/systemd/user")] {
        for entry in WalkDir::new(root)
            .max_depth(2)
            .into_iter()
            .filter_map(Result::ok)
        {
            if entry.path().extension().and_then(|value| value.to_str()) == Some("service")
                && fs::read_to_string(entry.path()).is_ok_and(|text| {
                    text.lines()
                        .any(|line| line.starts_with("ExecStart=") && persistence.is_match(line))
                })
            {
                hits.insert(format!("systemd:{}", entry.path().display()));
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
        if fs::read_to_string(&path).is_ok_and(|text| persistence.is_match(&text)) {
            hits.insert(format!("shell_rc:{}", path.display()));
        }
    }
    for entry in WalkDir::new(home.join(".config/autostart"))
        .max_depth(2)
        .into_iter()
        .filter_map(Result::ok)
    {
        if entry.path().extension().and_then(|value| value.to_str()) == Some("desktop")
            && fs::read_to_string(entry.path()).is_ok_and(|text| {
                text.lines()
                    .any(|line| line.starts_with("Exec=") && persistence.is_match(line))
            })
        {
            hits.insert(format!("autostart:{}", entry.path().display()));
        }
    }
    for path in [
        home.join(".config/systemd/user/gh-token-monitor.service"),
        home.join(".local/bin/gh-token-monitor.sh"),
        home.join(".config/gh-token-monitor"),
    ] {
        if path.exists() {
            hits.insert(format!("shai_hulud:{}", path.display()));
        }
    }
    hits
}

pub fn ebpf_iocs() -> BTreeSet<String> {
    ["hidden_pids", "hidden_names", "hidden_inodes"]
        .into_iter()
        .map(|name| PathBuf::from("/sys/fs/bpf").join(name))
        .filter(|path| path.exists())
        .map(|path| path.display().to_string())
        .collect()
}

pub fn cache_iocs(home: &Path, quick: bool) -> BTreeSet<String> {
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
    let mut hits = BTreeSet::new();
    for root in roots {
        for entry in WalkDir::new(root)
            .max_depth(if quick { 4 } else { 8 })
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
        {
            if PACKAGES
                .iter()
                .any(|package| entry.path().to_string_lossy().contains(package))
            {
                hits.insert(entry.path().display().to_string());
            }
            if entry.file_type().is_file() {
                if let Ok(bytes) = fs::read(entry.path()) {
                    let hash = format!("{:x}", Sha256::digest(bytes));
                    if MALWARE_HASHES.contains(&hash.as_str()) {
                        hits.insert(entry.path().display().to_string());
                    }
                }
            }
        }
    }
    hits
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_toolkit_processes() {
        assert!(process_is_noise("1 rg atomic-lockfile"));
        assert!(!process_is_noise("22 /var/lib/deps"));
    }
}
