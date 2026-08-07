use crate::alpm;
use crate::cli::{CommandKind, Parsed};
use crate::config::Config;
use crate::ioc;
use crate::lists;
use crate::model::{Campaign, FailOn, ScanState};
use crate::report;
use crate::{EXIT_CLEAN, EXIT_COMPROMISE, EXIT_INSUFFICIENT, EXIT_WARN};
use chrono::Local;
use regex::Regex;
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::io::{self, IsTerminal};
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

const HOOK_PATTERN: &str = r"atomic-lockfile|js-digest|lockfile-js|nextfile-js|crypto-javascript|linux-utils|bun install js-digest|npm install atomic-lockfile|npm install lockfile-js|npm install nextfile-js|npm install crypto-javascript|npm install linux-utils|sudo\s+(?:\./)?validator";
const HEURISTIC_PATTERN: &str = r"atomic-lockfile|js-digest|lockfile-js|nextfile-js|crypto-javascript|linux-utils|/var/lib/deps|bun (pm )?install|npm (ci|install).*(--ignore-scripts=false|--foreground-scripts)|cd\s+/tmp.*(?:npm|bun)|sudo\s+(?:\./)?[[:alnum:]_.+-]+|(?:^|[\s/])validator(?:\s|$)|node -e |eval \(|base64 -d|openssl enc|curl .*\| (bash|sh)|wget .*\| (bash|sh)|atob\(|Buffer\.from\(.*base64";
const MALWARE_HASHES: &[&str] = &[
    "6144d433f8a0316869877b5f834c801251bbb936e5f1577c5680878c7443c98b",
    "7883bda1ff15425f2dbe622c45a3ae105ddfa6175009bbf0b0cad9bf5c79b316",
    "47893d9badc38c54b71321263ce8178c1abb10396e0aadf9793e61ec8829e204",
];

#[derive(Clone, Debug)]
pub struct Paths {
    pub root: PathBuf,
    pub data_lists: PathBuf,
    pub reports: PathBuf,
    pub pacman_logs: PathBuf,
    pub pacman_local: PathBuf,
}

impl Paths {
    pub fn resolve(config: &Config) -> Self {
        let root = env::var_os("AUR_RESPONSE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| default_root(env::current_dir().ok()));
        let xdg = env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                env::var_os("HOME")
                    .map(PathBuf::from)
                    .unwrap_or_default()
                    .join(".local/share")
            })
            .join("aur-response");
        let reports = config.reports_dir.clone().unwrap_or_else(|| {
            let local = root.join("reports");
            if fs::metadata(&local).is_ok_and(|m| !m.permissions().readonly()) {
                local
            } else {
                xdg.join("reports")
            }
        });
        Self {
            data_lists: root.join("data/lists"),
            root,
            reports,
            pacman_logs: config
                .pacman_log_dir
                .clone()
                .or_else(|| env::var_os("AUR_TEST_PACMAN_LOG_DIR").map(PathBuf::from))
                .or_else(|| env::var_os("AUR_PACMAN_LOG_DIR").map(PathBuf::from))
                .unwrap_or_else(|| PathBuf::from("/var/log")),
            pacman_local: config
                .pacman_local_dir
                .clone()
                .or_else(|| env::var_os("AUR_PACMAN_LOCAL_DIR").map(PathBuf::from))
                .unwrap_or_else(|| PathBuf::from("/var/lib/pacman/local")),
        }
    }

    pub fn list(&self, campaign: Campaign, config: &Config) -> PathBuf {
        if campaign == Campaign::AtomicArch {
            if let Some(path) = env::var_os("AUR_TEST_LIST_FILE") {
                return PathBuf::from(path);
            }
        }
        match campaign {
            Campaign::AtomicArch => config.atomic_arch_list_file.clone(),
            Campaign::ChaosRat => config.chaos_rat_list_file.clone(),
            Campaign::ShaiHulud => config.shai_hulud_list_file.clone(),
            Campaign::OpenconnectSso => config.openconnect_sso_list_file.clone(),
            Campaign::BrowshLinuxUtils => config.browsh_linux_utils_list_file.clone(),
            Campaign::Xeactor => config.xeactor_list_file.clone(),
        }
        .unwrap_or_else(|| {
            self.data_lists
                .join(format!("{}-pkgs.txt", campaign.slug()))
        })
    }
}

fn default_root(working_dir: Option<PathBuf>) -> PathBuf {
    working_dir
        .as_deref()
        .and_then(|path| {
            path.ancestors()
                .find(|ancestor| ancestor.join("data/lists").is_dir())
        })
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("/usr/share/aur-response-toolkit"))
}

pub struct Engine {
    pub config: Config,
    pub paths: Paths,
    pub state: ScanState,
    local_mode: bool,
}

impl Engine {
    fn campaign_enabled(&self, options: &crate::model::RunOptions, slug: &str) -> bool {
        options.campaigns.contains(slug)
            || match slug {
                "chaos-rat" => self.config.enable_chaos_rat == Some(true),
                "shai-hulud" => self.config.enable_shai_hulud == Some(true),
                "openconnect-sso" => self.config.enable_openconnect_sso == Some(true),
                "browsh-linux-utils" => self.config.enable_browsh_linux_utils == Some(true),
                "xeactor" => self.config.enable_xeactor == Some(true),
                _ => false,
            }
    }

    pub fn new(config: Config) -> Self {
        let paths = Paths::resolve(&config);
        let compromised = fs::read_to_string(paths.reports.join(".scan-state"))
            .is_ok_and(|state| state.lines().any(|line| line == "compromised=1"));
        let state = ScanState {
            compromise: compromised,
            ..ScanState::default()
        };
        Self {
            config,
            paths,
            state,
            local_mode: true,
        }
    }

    fn read_list(&mut self, campaign: Campaign, quiet: bool) -> Option<BTreeSet<String>> {
        let path = self.paths.list(campaign, &self.config);
        if !self.local_mode {
            if let Some(fetched) = self.fetch_list(campaign, quiet) {
                return Some(fetched);
            }
        }
        match fs::read_to_string(&path) {
            Ok(input) => {
                let packages = input
                    .lines()
                    .map(str::trim)
                    .filter(|v| !v.is_empty() && !v.starts_with('#'))
                    .map(str::to_owned)
                    .collect::<BTreeSet<_>>();
                if packages.is_empty() {
                    self.insufficient(
                        quiet,
                        format!(
                            "{} package list is empty: {}",
                            campaign.slug(),
                            path.display()
                        ),
                    );
                    None
                } else {
                    Some(packages)
                }
            }
            Err(e) => {
                self.insufficient(
                    quiet,
                    format!(
                        "cannot read {} package list {}: {e}",
                        campaign.slug(),
                        path.display()
                    ),
                );
                None
            }
        }
    }

    fn fetch_list(&mut self, campaign: Campaign, quiet: bool) -> Option<BTreeSet<String>> {
        type Parser = fn(&str) -> BTreeSet<String>;
        let sources: Vec<(String, Parser)> = match campaign {
            Campaign::AtomicArch => vec![
                (
                    self.config
                        .list_url_arch
                        .clone()
                        .unwrap_or_else(|| "https://md.archlinux.org/s/SxbqukK6IA".into()),
                    lists::html_lines as Parser,
                ),
                (
                    self.config.list_url_cscs.clone().unwrap_or_else(|| {
                        "https://cscs.pastes.sh/raw/aurvulntest20260611.sh".into()
                    }),
                    lists::cscs_script as Parser,
                ),
                (
                    self.config.list_url_extra.clone().unwrap_or_default(),
                    lists::plain as Parser,
                ),
            ],
            Campaign::ChaosRat => vec![
                (
                    self.config.chaos_rat_url_arch.clone().unwrap_or_else(|| {
                        "https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/".into()
                    }),
                    lists::chaos_advisory as Parser,
                ),
                (
                    self.config.chaos_rat_url_community.clone().unwrap_or_else(|| {
                        "https://raw.githubusercontent.com/lenucksi/aur-malware-check/master/chaos_rat_packages.txt".into()
                    }),
                    lists::plain as Parser,
                ),
                (
                    self.config
                        .chaos_rat_url_extra
                        .clone()
                        .unwrap_or_default(),
                    lists::plain as Parser,
                ),
            ],
            Campaign::ShaiHulud => vec![(
                self.config.shai_hulud_url.clone().unwrap_or_default(),
                lists::plain as Parser,
            )],
            Campaign::OpenconnectSso => vec![(
                self.config
                    .openconnect_sso_url
                    .clone()
                    .unwrap_or_default(),
                lists::plain as Parser,
            )],
            Campaign::BrowshLinuxUtils => vec![(
                self.config
                    .browsh_linux_utils_url
                    .clone()
                    .unwrap_or_default(),
                lists::plain as Parser,
            )],
            Campaign::Xeactor => vec![(
                self.config.xeactor_url.clone().unwrap_or_default(),
                lists::plain as Parser,
            )],
        };
        let mut merged = BTreeSet::new();
        for (url, parser) in sources.into_iter().filter(|(url, _)| !url.is_empty()) {
            let output = Command::new("curl")
                .args(["-fsSL", "--max-time", "20", &url])
                .output();
            let Ok(output) = output else {
                continue;
            };
            if !output.status.success() {
                continue;
            }
            let input = String::from_utf8_lossy(&output.stdout);
            merged.extend(parser(&input));
        }
        if merged.is_empty() {
            return None;
        }

        let path = self.paths.list(campaign, &self.config);
        let old = fs::read_to_string(&path)
            .ok()
            .map(|input| lists::plain(&input));
        if let Some(old) = &old {
            self.state.counters.list_added += merged.difference(old).count() as u64;
            self.state.counters.list_removed += old.difference(&merged).count() as u64;
        }
        if let Err(error) = Self::cache_list(&path, &merged) {
            self.state.log(
                quiet,
                format!("WARN: cannot cache {} list: {error}", campaign.slug()),
            );
        }
        self.state.log(
            quiet,
            format!(
                "Fetched {} {} package-list entries",
                merged.len(),
                campaign.slug()
            ),
        );
        Some(merged)
    }

    fn cache_list(path: &Path, packages: &BTreeSet<String>) -> std::io::Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        if path.is_file() {
            let previous = path.with_extension("previous.txt");
            fs::copy(path, previous)?;
        }
        let temporary = path.with_extension("tmp");
        let contents = packages.iter().cloned().collect::<Vec<_>>().join("\n") + "\n";
        fs::write(&temporary, contents)?;
        fs::rename(temporary, path)
    }

    fn insufficient(&mut self, quiet: bool, reason: String) {
        self.state.insufficient = true;
        self.state.counters.insufficient_data += 1;
        self.state.finding("insufficient_data", reason.clone());
        self.state.log(quiet, format!("[INSUFFICIENT] {reason}"));
    }

    fn campaign(slug: &str) -> Option<Campaign> {
        match slug {
            "atomic-arch" => Some(Campaign::AtomicArch),
            "chaos-rat" => Some(Campaign::ChaosRat),
            "shai-hulud" => Some(Campaign::ShaiHulud),
            "openconnect-sso" => Some(Campaign::OpenconnectSso),
            "browsh-linux-utils" => Some(Campaign::BrowshLinuxUtils),
            "xeactor" => Some(Campaign::Xeactor),
            _ => None,
        }
    }

    fn window_regex(&self, campaign: Campaign) -> Option<&str> {
        match campaign {
            Campaign::ShaiHulud => self.config.shai_hulud_window_log_re.as_deref(),
            Campaign::Xeactor => self.config.xeactor_window_log_re.as_deref(),
            _ => None,
        }
    }

    fn window_label(&self, campaign: Campaign, default: &str) -> String {
        match campaign {
            Campaign::ShaiHulud => self
                .config
                .shai_hulud_window_label
                .as_deref()
                .unwrap_or(default)
                .to_owned(),
            Campaign::Xeactor => self
                .config
                .xeactor_window_label
                .as_deref()
                .unwrap_or(default)
                .to_owned(),
            _ => default.to_owned(),
        }
    }

    fn mock_package_window(&self, package: &str, campaign: Campaign) -> Option<bool> {
        let path = env::var_os("AUR_TEST_PKG_INFO")?;
        let input = fs::read_to_string(path).ok()?;
        let row = input
            .lines()
            .find(|line| line.starts_with(&format!("{package}|")))?;
        let fields = row.split('|').collect::<Vec<_>>();
        if let Some(epoch) = fields.get(3).and_then(|value| value.parse::<i64>().ok()) {
            let (start, end, _) = campaign.window();
            let start = chrono::NaiveDate::parse_from_str(start, "%Y-%m-%d")
                .ok()?
                .and_hms_opt(0, 0, 0)?
                .and_utc()
                .timestamp();
            let end = chrono::NaiveDate::parse_from_str(end, "%Y-%m-%d")
                .ok()?
                .and_hms_opt(23, 59, 59)?
                .and_utc()
                .timestamp();
            return Some(epoch >= start && epoch <= end);
        }
        let date = *fields.get(1)?;
        if campaign == Campaign::ShaiHulud {
            let days = self
                .config
                .shai_hulud_window_install_days_re
                .as_deref()
                .unwrap_or("(1[6-9]|2[0-8])");
            let month = self
                .config
                .shai_hulud_window_install_month
                .as_deref()
                .unwrap_or("May");
            return Regex::new(days).ok().map(|pattern| {
                pattern.is_match(date) && date.contains(month) && date.contains("2026")
            });
        }
        None
    }

    fn scan_packages(&mut self, campaign: Campaign, all_time: bool, quiet: bool) {
        let Some(list) = self.read_list(campaign, quiet) else {
            return;
        };
        let installed = match alpm::installed_packages() {
            Ok(v) => v,
            Err(e) => {
                self.insufficient(
                    quiet,
                    format!("could not query installed foreign packages: {e}"),
                );
                return;
            }
        };
        let epochs = alpm::package_install_epochs(&self.paths.pacman_local).unwrap_or_default();
        let (start, end, default_label) = campaign.window();
        let label = self.window_label(campaign, default_label);
        let start = chrono::NaiveDate::parse_from_str(start, "%Y-%m-%d")
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap()
            .and_utc()
            .timestamp();
        let end = chrono::NaiveDate::parse_from_str(end, "%Y-%m-%d")
            .unwrap()
            .and_hms_opt(23, 59, 59)
            .unwrap()
            .and_utc()
            .timestamp();
        for pkg in installed.intersection(&list) {
            let high = all_time
                || self.mock_package_window(pkg, campaign).unwrap_or(false)
                || epochs
                    .get(pkg)
                    .is_some_and(|epoch| *epoch >= start && *epoch <= end);
            let prefix = campaign.finding_prefix();
            self.state.finding(format!("{prefix}_installed"), pkg);
            if high {
                self.state.finding(format!("{prefix}_high_risk"), pkg);
            }
            let severity = if high { "HIGH" } else { "LOW" };
            let classification = if high {
                "during campaign window".to_owned()
            } else {
                format!("outside {label}")
            };
            self.state.log(
                quiet,
                format!("  [{severity}] {pkg} — installed {classification}"),
            );
            match campaign {
                Campaign::AtomicArch => {
                    self.state.counters.atomic_arch_installed += 1;
                    if high {
                        self.state.counters.atomic_arch_high_risk += 1;
                    }
                    if high {
                        self.state.compromise = true;
                    } else {
                        self.state.warning = true;
                    }
                }
                Campaign::ChaosRat => {
                    self.state.counters.chaos_rat_installed += 1;
                    if high {
                        self.state.counters.chaos_rat_high_risk += 1;
                    }
                    self.state.optional_warnings.insert("chaos-rat".into());
                }
                Campaign::ShaiHulud => {
                    self.state.counters.shai_hulud_installed += 1;
                    if high {
                        self.state.counters.shai_hulud_high_risk += 1;
                    }
                    self.state.optional_warnings.insert("shai-hulud".into());
                }
                Campaign::OpenconnectSso => {
                    self.state.counters.openconnect_sso_installed += 1;
                    if high {
                        self.state.counters.openconnect_sso_high_risk += 1;
                    }
                    self.state
                        .optional_warnings
                        .insert("openconnect-sso".into());
                }
                Campaign::BrowshLinuxUtils => {
                    self.state.counters.browsh_linux_utils_installed += 1;
                    if high {
                        self.state.counters.browsh_linux_utils_high_risk += 1;
                    }
                    self.state
                        .optional_warnings
                        .insert("browsh-linux-utils".into());
                }
                Campaign::Xeactor => {
                    self.state.counters.xeactor_installed += 1;
                    if high {
                        self.state.counters.xeactor_high_risk += 1;
                    }
                    self.state.optional_warnings.insert("xeactor".into());
                }
            }
        }
    }

    fn scan_timeline(&mut self, campaign: Campaign, all_time: bool, quiet: bool) {
        let Some(list) = self.read_list(campaign, quiet) else {
            return;
        };
        let events = match alpm::events_with_window(
            &self.paths.pacman_logs,
            campaign,
            all_time,
            self.window_regex(campaign),
        ) {
            Ok(v) => v,
            Err(e) => {
                self.insufficient(quiet, format!("pacman logs could not be read: {e}"));
                return;
            }
        };
        let hits = alpm::timeline_hits(&events, &list);
        let total = hits.values().map(Vec::len).sum::<usize>();
        let (_, _, default_label) = campaign.window();
        let label = self.window_label(campaign, default_label);
        self.state.log(quiet, "=== Pacman install timeline ===");
        self.state.log(
            quiet,
            format!("Scanning pacman logs for infected packages, {label}"),
        );
        self.state.log(quiet, "");
        if total > 0 {
            self.state
                .log(quiet, format!("[FOUND] {total} timeline hit(s):"));
        }
        for (pkg, lines) in hits {
            let prefix = campaign.finding_prefix();
            for line in &lines {
                self.state.finding(format!("{prefix}_timeline_hits"), line);
                self.state.log(quiet, format!("  {line}"));
            }
            match campaign {
                Campaign::AtomicArch => {
                    self.state.counters.atomic_arch_timeline_hits += lines.len() as u64;
                    if lines.len() > 1 {
                        self.state.counters.atomic_arch_timeline_repeat_updates += 1;
                        self.state.finding(
                            "atomic_arch_timeline_repeat_updates",
                            format!("{}|{}|{}", pkg, lines.len(), lines.join(" ;; ")),
                        );
                        self.state.log(
                            quiet,
                            format!("  [REPEAT] {pkg} — {} updates during {label}:", lines.len()),
                        );
                        for line in &lines {
                            self.state.log(quiet, format!("           {line}"));
                        }
                        self.state.log(quiet, "           earliest update may have pulled malware; later update may be post-takedown");
                    }
                    self.state.compromise = true;
                }
                Campaign::ChaosRat => {
                    self.state.counters.chaos_rat_timeline_hits += lines.len() as u64;
                    self.state.optional_warnings.insert("chaos-rat".into());
                }
                Campaign::ShaiHulud => {
                    self.state.counters.shai_hulud_timeline_hits += lines.len() as u64;
                    self.state.optional_warnings.insert("shai-hulud".into());
                }
                Campaign::OpenconnectSso => {
                    self.state.counters.openconnect_sso_timeline_hits += lines.len() as u64;
                    self.state
                        .optional_warnings
                        .insert("openconnect-sso".into());
                }
                Campaign::BrowshLinuxUtils => {
                    self.state.counters.browsh_linux_utils_timeline_hits += lines.len() as u64;
                    self.state
                        .optional_warnings
                        .insert("browsh-linux-utils".into());
                }
                Campaign::Xeactor => {
                    self.state.counters.xeactor_timeline_hits += lines.len() as u64;
                    self.state.optional_warnings.insert("xeactor".into());
                }
            }
        }
    }

    fn artifact_roots(&self, quick: bool) -> Vec<PathBuf> {
        if let Some(paths) = env::var_os("AUR_DEPS_SEARCH_PATHS") {
            return env::split_paths(&paths).collect();
        }
        if !self.config.deps_search_paths.is_empty() {
            let mut roots = self.config.deps_search_paths.clone();
            roots.extend(self.config.helper_cache_roots.clone());
            return roots;
        }
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let mut roots = vec![
            home.join(".cache"),
            home.join(".local"),
            home.join(".npm"),
            home.join(".bun/install/cache"),
        ];
        if !quick {
            roots.extend([PathBuf::from("/var/tmp"), PathBuf::from("/var/lib")]);
        }
        roots.extend(self.config.helper_cache_roots.clone());
        roots.extend([
            home.join(".cache/paru/clone"),
            home.join(".cache/yay"),
            home.join(".cache/pikaur"),
            home.join("abs"),
            home.join("builds"),
            home.join("aur"),
        ]);
        roots
    }

    fn scan_artifacts(&mut self, quick: bool, quiet: bool) {
        let hook = Regex::new(HOOK_PATTERN).unwrap();
        for root in self.artifact_roots(quick) {
            if !root.exists() {
                continue;
            }
            for entry in WalkDir::new(root)
                .follow_links(false)
                .max_depth(if quick { 6 } else { 12 })
                .into_iter()
                .filter_map(Result::ok)
            {
                if !entry.file_type().is_file() {
                    continue;
                }
                let path = entry.path();
                let name = path
                    .file_name()
                    .and_then(|v| v.to_str())
                    .unwrap_or_default();
                let path_text = path.to_string_lossy();
                let suspicious_name =
                    matches!(name, "deps" | "PKGBUILD" | ".INSTALL" | "validator")
                        || [
                            "atomic-lockfile",
                            "js-digest",
                            "lockfile-js",
                            "nextfile-js",
                            "crypto-javascript",
                            "linux-utils",
                            "openconnect-sso",
                            "browsh-bin",
                        ]
                        .iter()
                        .any(|v| path_text.contains(v));
                if !suspicious_name {
                    continue;
                }
                let bytes = match fs::read(path) {
                    Ok(v) => v,
                    Err(_) => continue,
                };
                let hash = format!("{:x}", Sha256::digest(&bytes));
                let text_hit = std::str::from_utf8(&bytes).is_ok_and(|v| hook.is_match(v));
                let embedded_elf = (path_text.contains("linux-utils")
                    || path_text.contains("node_modules")
                    || path_text.contains("/.npm/"))
                    && bytes.windows(4).any(|window| window == b"\x7fELF");
                if MALWARE_HASHES.contains(&hash.as_str()) || text_hit || embedded_elf {
                    let item = path.display().to_string();
                    self.state.finding("artifacts", &item);
                    self.state.counters.artifact_critical += 1;
                    self.state.compromise = true;
                    self.state.log(quiet, format!("  [CRITICAL] {item}"));
                }
            }
        }
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        for item in ioc::cache_iocs(&home, quick) {
            self.record_critical(quiet, "artifacts", item);
        }
        for item in ioc::runtime_iocs(&home) {
            self.state.counters.runtime_iocs += 1;
            self.record_critical(quiet, "runtime_iocs", item);
        }
        for item in ioc::persistence_iocs(&home) {
            self.record_critical(quiet, "artifacts", item);
        }
        for item in ioc::ebpf_iocs() {
            self.record_critical(quiet, "artifacts", item);
        }
        if self.paths.pacman_local.is_dir() {
            for entry in WalkDir::new(&self.paths.pacman_local)
                .max_depth(3)
                .into_iter()
                .filter_map(Result::ok)
            {
                if entry.file_name() != "install" || !entry.file_type().is_file() {
                    continue;
                }
                if fs::read_to_string(entry.path()).is_ok_and(|text| hook.is_match(&text)) {
                    self.record_critical(quiet, "artifacts", entry.path().display().to_string());
                }
            }
        } else {
            self.insufficient(
                quiet,
                format!(
                    "pacman local db not readable: {}",
                    self.paths.pacman_local.display()
                ),
            );
        }
    }

    fn record_critical(&mut self, quiet: bool, category: &str, item: String) {
        let inserted = self
            .state
            .findings
            .entry(category.to_owned())
            .or_default()
            .insert(item.clone());
        if inserted {
            self.state.counters.artifact_critical += 1;
            self.state.compromise = true;
            self.state.log(quiet, format!("  [CRITICAL] {item}"));
        }
    }

    fn scan_similar(&mut self, quick: bool, quiet: bool) {
        let pattern = self
            .config
            .similar_heuristics_pattern
            .as_deref()
            .unwrap_or(HEURISTIC_PATTERN);
        let Ok(re) = Regex::new(pattern) else {
            self.insufficient(
                quiet,
                "invalid similar-heuristics regular expression".into(),
            );
            return;
        };
        for root in self.artifact_roots(quick) {
            for entry in WalkDir::new(root)
                .follow_links(false)
                .max_depth(if quick { 5 } else { 10 })
                .into_iter()
                .filter_map(Result::ok)
            {
                if !matches!(
                    entry.file_name().to_str(),
                    Some("PKGBUILD" | ".INSTALL" | "install")
                ) {
                    continue;
                }
                let Ok(input) = fs::read_to_string(entry.path()) else {
                    continue;
                };
                if re.is_match(&input)
                    && !input
                        .lines()
                        .any(|v| v.starts_with("# Maintainer:") && v.contains("base64 -d"))
                {
                    let item = entry.path().display().to_string();
                    self.state.finding("artifacts", &item);
                    self.state.counters.artifact_critical += 1;
                    self.state.compromise = true;
                    self.state.log(
                        quiet,
                        format!("  [CRITICAL] campaign-like PKGBUILD: {item}"),
                    );
                }
            }
        }
    }

    fn scan_aur_window(&mut self, quiet: bool) {
        let Some(known) = self.read_list(Campaign::AtomicArch, quiet) else {
            return;
        };
        let foreign = match alpm::foreign_packages() {
            Ok(value) => value,
            Err(error) => {
                self.insufficient(
                    quiet,
                    format!("could not query installed foreign packages: {error}"),
                );
                return;
            }
        };
        let events = match alpm::events(&self.paths.pacman_logs, Campaign::AtomicArch, false) {
            Ok(value) => value,
            Err(error) => {
                self.insufficient(quiet, format!("pacman logs could not be read: {error}"));
                return;
            }
        };
        let mut touched = BTreeSet::new();
        let mut known_lines = Vec::new();
        for event in events {
            if foreign.contains(&event.package) {
                if known.contains(&event.package) {
                    known_lines.push(event.line);
                }
                touched.insert(event.package);
            }
        }
        self.state.counters.window_aur_pkgs = touched.len() as u64;
        for package in touched {
            if known.contains(&package) {
                self.state.compromise = true;
                self.state.log(
                    quiet,
                    format!("  [CRITICAL] {package} — known infected package in campaign window"),
                );
            } else {
                self.state.finding("unknown_window_pkgs", &package);
                self.state.warning = true;
                self.state.log(
                    quiet,
                    format!("  [REVIEW] {package} — foreign package active in campaign window"),
                );
            }
        }
        for line in known_lines {
            self.state.finding("atomic_arch_timeline_hits", line);
        }
    }

    fn scan_hardening(&mut self, quiet: bool) {
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let npmrc = fs::read_to_string(home.join(".npmrc")).unwrap_or_default();
        if !npmrc.lines().any(|v| v.trim() == "ignore-scripts=true") {
            self.state.counters.hardening_warn += 1;
            self.state.warning = true;
            self.state
                .finding("hardening", "npm ignore-scripts disabled");
            self.state
                .log(quiet, "  [WARN] npm ignore-scripts is not enabled");
        }
        for variable in ["BUN_INSTALL", "BUN_INSTALL_BIN"] {
            if env::var_os(variable).is_some() {
                self.hardening_warning(quiet, format!("{variable} is set"));
            }
        }
        let unsafe_helper =
            Regex::new(r"(?i)NoReview|noconfirm|NoConfirm|noConfirm|NoEdit").unwrap();
        for path in [
            home.join(".config/paru/paru.conf"),
            home.join(".config/yay/config.json"),
            PathBuf::from("/etc/pamac.conf"),
            home.join(".config/pamac/config"),
            home.join(".config/trizen/trizen.conf"),
            home.join(".config/aura/config.json"),
            home.join(".config/aurman/aurman.conf"),
        ] {
            if fs::read_to_string(&path).is_ok_and(|text| unsafe_helper.is_match(&text)) {
                self.hardening_warning(
                    quiet,
                    format!("{} may skip PKGBUILD review", path.display()),
                );
            }
        }
        let helpers = self
            .config
            .history_helpers
            .as_deref()
            .unwrap_or("paru|yay|pamac|pikaur|trizen|aura|aurman|pacaur|makepkg");
        let risky = Regex::new(&format!(
            r"(?i)(?:{helpers}).*(?:--noconfirm|--no-confirm|--batch|--noedit)|(?:--noconfirm|--no-confirm|--batch|--noedit).*(?:{helpers})"
        ))
        .ok();
        let foreign_activity = alpm::events(&self.paths.pacman_logs, Campaign::AtomicArch, false)
            .ok()
            .zip(alpm::foreign_packages().ok())
            .is_some_and(|(events, foreign)| {
                events.iter().any(|event| foreign.contains(&event.package))
            });
        for path in Self::history_paths(&home) {
            if risky.as_ref().is_some_and(|pattern| {
                fs::read_to_string(&path).is_ok_and(|text| pattern.is_match(&text))
            }) && foreign_activity
            {
                self.hardening_warning(
                    quiet,
                    format!(
                        "AUR helper auto-install flags in {} during campaign window",
                        path.display()
                    ),
                );
            }
        }
    }

    fn hardening_warning(&mut self, quiet: bool, item: String) {
        self.state.counters.hardening_warn += 1;
        self.state.warning = true;
        self.state.finding("hardening", &item);
        self.state.log(quiet, format!("  [WARN] {item}"));
    }

    fn history_paths(home: &Path) -> Vec<PathBuf> {
        vec![
            home.join(".bash_history"),
            home.join(".zsh_history"),
            home.join(".local/share/fish/fish_history"),
        ]
    }

    fn audit(&mut self, quiet: bool, if_compromised: bool) {
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let candidates = [
            (
                "audit_git_paths",
                home.join(".git-credentials"),
                "Git credentials",
            ),
            (
                "audit_git_paths",
                home.join(".config/gh/hosts.yml"),
                "GitHub credentials",
            ),
            (
                "audit_docker_paths",
                home.join(".docker/config.json"),
                "Docker credentials",
            ),
            (
                "audit_docker_paths",
                home.join(".kube/config"),
                "Kubernetes credentials",
            ),
            (
                "audit_docker_paths",
                home.join(".aws/credentials"),
                "AWS credentials",
            ),
            (
                "audit_docker_paths",
                home.join(".config/containers/auth.json"),
                "Container credentials",
            ),
        ];
        let mut found = 0;
        for entry in WalkDir::new(home.join(".ssh"))
            .max_depth(1)
            .into_iter()
            .filter_map(Result::ok)
        {
            let name = entry.file_name().to_string_lossy();
            if entry.file_type().is_file()
                && (name.starts_with("id_") || name.contains('@'))
                && !name.ends_with(".pub")
            {
                let item = entry.path().display().to_string();
                self.state.finding("audit_ssh_keys", &item);
                self.state
                    .log(quiet, format!("  [INVENTORY] private key: {item}"));
                found += 1;
            }
        }
        for (category, path, label) in candidates {
            if path.exists() {
                self.state.finding(category, path.display().to_string());
                self.state
                    .log(quiet, format!("  [AUDIT] {label}: {}", path.display()));
                found += 1;
            }
        }
        let secret = Regex::new(r"(?i)password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword").unwrap();
        for path in Self::history_paths(&home) {
            if fs::read_to_string(&path).is_ok_and(|text| secret.is_match(&text)) {
                self.state
                    .finding("audit_history_files", path.display().to_string());
                self.state.log(
                    quiet,
                    format!(
                        "  [INVENTORY] potential secret references: {}",
                        path.display()
                    ),
                );
                found += 1;
            }
        }
        let dev_root = self
            .config
            .dev_root
            .clone()
            .unwrap_or_else(|| home.join("dev"));
        for entry in WalkDir::new(dev_root)
            .max_depth(5)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
        {
            if !entry.file_type().is_file() {
                continue;
            }
            let name = entry.file_name().to_string_lossy();
            if matches!(
                name.as_ref(),
                ".env" | "secrets.env" | "stack.env" | "shared.env" | "harbor.yml"
            ) {
                self.state
                    .finding("audit_env_files", entry.path().display().to_string());
                found += 1;
            }
        }
        self.state.counters.credential_exposed = found;
        if found > 0 && !if_compromised {
            self.state.warning = true;
        }
        for (label, path) in [
            (
                "Brave cookies",
                home.join(".config/BraveSoftware/Brave-Browser/Default/Cookies"),
            ),
            (
                "Chrome cookies",
                home.join(".config/google-chrome/Default/Cookies"),
            ),
            (
                "Chromium cookies",
                home.join(".config/chromium/Default/Cookies"),
            ),
            ("Firefox profiles", home.join(".mozilla/firefox")),
            ("Discord", home.join(".config/discord")),
            ("Slack", home.join(".config/Slack")),
            ("npm token/config", home.join(".npmrc")),
            ("Vault token", home.join(".vault-token")),
            ("GPG keyring", home.join(".gnupg/pubring.kbx")),
        ] {
            if path.exists() {
                self.state
                    .log(quiet, format!("  [INVENTORY] {label}: {}", path.display()));
            }
        }
    }

    fn remove_packages(&mut self, parsed: &Parsed) -> i32 {
        let args = &parsed.positionals;
        let dry_run = args.iter().any(|v| v == "--dry-run");
        let force = args.iter().any(|v| v == "--force");
        let verify = args.iter().any(|v| v == "--verify");
        let list_slug = args
            .windows(2)
            .find(|w| w[0] == "--list")
            .map(|w| w[1].as_str())
            .unwrap_or("atomic-arch");
        let Some(campaign) = Self::campaign(list_slug) else {
            eprintln!("ERROR: unknown list type '{list_slug}' (use atomic-arch, chaos-rat, shai-hulud, openconnect-sso, browsh-linux-utils, or xeactor)");
            return crate::EXIT_INVALID;
        };
        let explicit = args
            .iter()
            .filter(|v| !v.starts_with("--") && v.as_str() != list_slug)
            .cloned()
            .collect::<BTreeSet<_>>();
        let installed = match alpm::installed_packages() {
            Ok(v) => v,
            Err(e) => {
                eprintln!("ERROR: could not query installed packages: {e}");
                return EXIT_INSUFFICIENT;
            }
        };
        let packages = if explicit.is_empty() {
            let Some(list) = self.read_list(campaign, false) else {
                return EXIT_INSUFFICIENT;
            };
            installed
                .intersection(&list)
                .cloned()
                .collect::<BTreeSet<_>>()
        } else {
            explicit
        };
        let label = match campaign {
            Campaign::AtomicArch => "Atomic Arch",
            Campaign::ChaosRat => "Chaos RAT",
            Campaign::ShaiHulud => "Shai-Hulud",
            Campaign::OpenconnectSso => "OpenConnect SSO",
            Campaign::BrowshLinuxUtils => "browsh/linux-utils",
            Campaign::Xeactor => "xeactor",
        };
        if verify {
            if packages.is_empty() {
                println!("VERIFY OK: no {label} packages remain installed.");
                return EXIT_CLEAN;
            }
            println!(
                "VERIFY FAILED: {} {label} package(s) still installed:",
                packages.len()
            );
            for pkg in packages {
                println!("  - {pkg}");
            }
            return if campaign == Campaign::AtomicArch {
                EXIT_COMPROMISE
            } else {
                EXIT_WARN
            };
        }
        if packages.is_empty() {
            println!("No {label} packages currently installed.");
            return EXIT_CLEAN;
        }
        println!("Packages to remove ({}):", packages.len());
        for pkg in &packages {
            println!("  - {pkg}");
        }
        println!(
            "\nCommand: sudo pacman -Rns {}",
            packages.iter().cloned().collect::<Vec<_>>().join(" ")
        );
        if dry_run {
            println!("[--dry-run] not executing");
            return EXIT_CLEAN;
        }
        if !force && !io::stdin().is_terminal() {
            eprintln!("ERROR: non-interactive terminal requires --force (or use --dry-run).");
            return crate::EXIT_INVALID;
        }
        if !force {
            print!("Proceed? [y/N] ");
            let _ = io::stdout().flush();
            let mut answer = String::new();
            let _ = io::stdin().read_line(&mut answer);
            if !answer.to_ascii_lowercase().starts_with('y') {
                println!("Aborted.");
                return EXIT_CLEAN;
            }
        }
        let status = Command::new("sudo")
            .arg("pacman")
            .arg("-Rns")
            .args(&packages)
            .status();
        match status {
            Ok(v) => v.code().unwrap_or(EXIT_INSUFFICIENT),
            Err(e) => {
                eprintln!("ERROR: failed to execute pacman: {e}");
                EXIT_INSUFFICIENT
            }
        }
    }

    fn scrub_history(&mut self, parsed: &Parsed) -> i32 {
        let dry = parsed.positionals.iter().any(|v| v == "--dry-run");
        let all = parsed.positionals.iter().any(|v| v == "--all-shells");
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let mut paths = vec![home.join(".local/share/fish/fish_history")];
        if all {
            paths.extend([home.join(".bash_history"), home.join(".zsh_history")]);
        }
        let pattern = Regex::new(r"(?i)password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword").unwrap();
        println!("Shell history scrub");
        for path in paths {
            if !path.is_file() {
                println!("  Skip: {} (not found)", path.display());
                continue;
            }
            let Ok(input) = fs::read_to_string(&path) else {
                continue;
            };
            let kept = input
                .lines()
                .filter(|line| !pattern.is_match(line))
                .collect::<Vec<_>>();
            let removed = input.lines().count() - kept.len();
            println!(
                "  {} — {} lines, {removed} matched",
                path.display(),
                input.lines().count()
            );
            if removed == 0 {
                continue;
            }
            let stamp = Local::now().format("%Y%m%d-%H%M%S");
            let backup = PathBuf::from(format!("{}.bak.{stamp}", path.display()));
            if dry {
                println!(
                    "    [--dry-run] Would backup to {} and remove {removed} lines",
                    backup.display()
                );
                continue;
            }
            if let Err(e) = fs::copy(&path, &backup).and_then(|_| {
                crate::config::atomic_write(&path, format!("{}\n", kept.join("\n")).as_bytes())
            }) {
                eprintln!("ERROR: failed to scrub {}: {e}", path.display());
                return EXIT_INSUFFICIENT;
            }
            println!("    Backup: {}", backup.display());
            println!("    Removed: {removed} lines");
        }
        println!("Done. Rotate any credentials that were in redacted lines first.");
        EXIT_CLEAN
    }

    fn rotate_hints(&mut self, quiet: bool) {
        let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let findings =
            fs::read_to_string(self.paths.reports.join(".scan-findings.list")).unwrap_or_default();
        let stored = |category: &str| {
            findings
                .lines()
                .filter_map(|line| line.split_once('\t'))
                .filter(|(key, _)| *key == category)
                .map(|(_, value)| PathBuf::from(value))
                .collect::<Vec<_>>()
        };
        let mut ssh = stored("audit_ssh_keys");
        if ssh.is_empty() {
            ssh = WalkDir::new(home.join(".ssh"))
                .max_depth(1)
                .into_iter()
                .filter_map(Result::ok)
                .filter(|entry| {
                    let name = entry.file_name().to_string_lossy();
                    entry.file_type().is_file()
                        && name.starts_with("id_")
                        && !name.ends_with(".pub")
                })
                .map(|entry| entry.into_path())
                .collect();
        }
        if !ssh.is_empty() {
            self.state.log(quiet, "## SSH");
            for key in ssh {
                self.state.log(
                    quiet,
                    format!("  ssh-keygen -t ed25519 -f {}.new", key.display()),
                );
            }
        }
        if home.join(".config/gh/hosts.yml").exists() || home.join(".git-credentials").exists() {
            self.state
                .log(quiet, "## GitHub\n  gh auth logout\n  gh auth login");
        }
        let docker = home.join(".docker/config.json");
        if let Ok(input) = fs::read_to_string(&docker) {
            self.state.log(quiet, "## Docker registries");
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&input) {
                if let Some(auths) = json.get("auths").and_then(|value| value.as_object()) {
                    for registry in auths.keys() {
                        self.state.log(quiet, format!("  docker logout {registry}"));
                    }
                }
            }
        }
        if home.join(".npmrc").exists() {
            self.state.log(
                quiet,
                "## npm\n  npm logout\n  # revoke tokens and enable ignore-scripts",
            );
        }
        self.state.log(
            quiet,
            "After rotation: aur-response recovery scrub-history --all-shells --dry-run",
        );
    }

    fn recovery_wizard(&mut self, quiet: bool) {
        if !self.state.compromise {
            return;
        }
        self.state.log(quiet, "=== Recovery wizard ===");
        let Ok(binary) = env::current_exe() else {
            return;
        };
        let run = |args: &[&str]| Command::new(&binary).args(args).status();
        let _ = run(&["recovery", "remove-packages", "--local", "--dry-run"]);
        print!("Run package removal now? [y/N] ");
        let _ = io::stdout().flush();
        let mut answer = String::new();
        let _ = io::stdin().read_line(&mut answer);
        if answer.to_ascii_lowercase().starts_with('y') {
            let _ = run(&["recovery", "remove-packages", "--local"]);
            let _ = run(&["recovery", "remove-packages", "--local", "--verify"]);
        }
        let _ = run(&["recovery", "rotate-hints"]);
        let _ = run(&["recovery", "scrub-history", "--all-shells", "--dry-run"]);
        print!("Scrub shell histories (all shells)? [y/N] ");
        let _ = io::stdout().flush();
        answer.clear();
        let _ = io::stdin().read_line(&mut answer);
        if answer.to_ascii_lowercase().starts_with('y') {
            let _ = run(&["recovery", "scrub-history", "--all-shells"]);
        }
        self.state
            .log(quiet, "=== Post-recovery verification scan ===");
        let pkg = run(&[
            "scan",
            "packages",
            "atomic-arch",
            "--local",
            "--quiet",
            "--quick",
        ]);
        let artifacts = run(&["scan", "malware-artifacts", "--quiet", "--quick"]);
        if pkg.is_ok_and(|status| status.success())
            && artifacts.is_ok_and(|status| status.success())
        {
            self.state.log(
                quiet,
                "[OK] Post-recovery quick scan found no compromise indicators.",
            );
        } else {
            self.state.log(
                quiet,
                "[WARN] Post-recovery scan still reports compromise indicators.",
            );
        }
    }

    fn final_exit(&self, fail_on: FailOn) -> i32 {
        if self.state.insufficient && matches!(fail_on, FailOn::All | FailOn::Compromise) {
            return EXIT_INSUFFICIENT;
        }
        if self.state.compromise && !matches!(fail_on, FailOn::None) {
            return EXIT_COMPROMISE;
        }
        let optional = match fail_on {
            FailOn::ChaosRat => self.state.optional_warnings.contains("chaos-rat"),
            FailOn::ShaiHulud => self.state.optional_warnings.contains("shai-hulud"),
            FailOn::OpenconnectSso => self.state.optional_warnings.contains("openconnect-sso"),
            FailOn::BrowshLinuxUtils => self.state.optional_warnings.contains("browsh-linux-utils"),
            FailOn::Xeactor => self.state.optional_warnings.contains("xeactor"),
            FailOn::All => !self.state.optional_warnings.is_empty(),
            _ => false,
        };
        if optional || (self.state.warning && matches!(fail_on, FailOn::All)) {
            EXIT_WARN
        } else {
            EXIT_CLEAN
        }
    }

    pub fn execute(&mut self, parsed: &Parsed) -> i32 {
        let o = &parsed.options;
        if o.recover && !io::stdin().is_terminal() {
            eprintln!("error: --recover requires an interactive terminal");
            return crate::EXIT_INVALID;
        }
        self.local_mode = o.local;
        if matches!(parsed.kind, CommandKind::Full) {
            self.state = ScanState::default();
        }
        if o.report {
            self.state.report_file = Some(self.paths.reports.join(format!(
                "full-scan-{}.log",
                Local::now().format("%Y%m%d-%H%M%S")
            )));
        }
        match &parsed.kind {
            CommandKind::Full => {
                self.state.log(o.quiet, format!("############################################\n# AUR malware response — full scan v{}\n############################################", crate::VERSION));
                if !o.skip_pkg_check {
                    self.scan_packages(Campaign::AtomicArch, o.all_time, o.quiet);
                }
                for slug in [
                    "chaos-rat",
                    "shai-hulud",
                    "openconnect-sso",
                    "browsh-linux-utils",
                    "xeactor",
                ] {
                    if self.campaign_enabled(o, slug) {
                        self.scan_packages(Self::campaign(slug).unwrap(), o.all_time, o.quiet);
                    }
                }
                self.scan_aur_window(o.quiet);
                self.scan_timeline(Campaign::AtomicArch, o.all_time, o.quiet);
                for slug in [
                    "chaos-rat",
                    "shai-hulud",
                    "openconnect-sso",
                    "browsh-linux-utils",
                    "xeactor",
                ] {
                    if self.campaign_enabled(o, slug) {
                        self.scan_timeline(Self::campaign(slug).unwrap(), o.all_time, o.quiet);
                    }
                }
                self.scan_artifacts(o.quick, o.quiet);
                self.scan_similar(o.quick, o.quiet);
                self.scan_hardening(o.quiet);
                if o.audit || self.state.compromise {
                    self.audit(o.quiet, o.if_compromised);
                }
                if o.recover {
                    self.recovery_wizard(o.quiet);
                }
            }
            CommandKind::Package(slug) => {
                self.scan_packages(Self::campaign(slug).unwrap(), o.all_time, o.quiet)
            }
            CommandKind::Timeline(slug) => {
                self.scan_timeline(Self::campaign(slug).unwrap(), o.all_time, o.quiet)
            }
            CommandKind::MalwareArtifacts => self.scan_artifacts(o.quick, o.quiet),
            CommandKind::SimilarHeuristics => self.scan_similar(o.quick, o.quiet),
            CommandKind::AurWindow => self.scan_aur_window(o.quiet),
            CommandKind::Hardening => self.scan_hardening(o.quiet),
            CommandKind::Audit => self.audit(o.quiet, o.if_compromised),
            CommandKind::ListFreshness => {
                if self.read_list(Campaign::AtomicArch, o.quiet).is_none() {
                    self.state.insufficient = true;
                }
            }
            CommandKind::RotateHints => self.rotate_hints(o.quiet),
            CommandKind::ApplyHardening => {
                let apply = parsed.positionals.iter().any(|v| v == "--apply");
                let path = env::var_os("HOME")
                    .map(PathBuf::from)
                    .unwrap_or_default()
                    .join(".npmrc");
                if apply {
                    let already_applied = fs::read_to_string(&path)
                        .is_ok_and(|input| input.lines().any(|line| line == "ignore-scripts=true"));
                    let result = if already_applied {
                        Ok(())
                    } else {
                        OpenOptions::new()
                            .create(true)
                            .append(true)
                            .open(&path)
                            .and_then(|mut f| writeln!(f, "ignore-scripts=true"))
                    };
                    if let Err(e) = result {
                        self.insufficient(
                            o.quiet,
                            format!("cannot update {}: {e}", path.display()),
                        );
                    } else {
                        self.state.log(
                            o.quiet,
                            format!("Applied ignore-scripts=true to {}", path.display()),
                        );
                    }
                } else {
                    self.state.log(
                        o.quiet,
                        format!(
                            "Dry run: would add ignore-scripts=true to {}",
                            path.display()
                        ),
                    );
                }
            }
            CommandKind::RemovePackages => return self.remove_packages(parsed),
            CommandKind::ScrubHistory => return self.scrub_history(parsed),
            CommandKind::ConfigMigrate => unreachable!(),
        }
        let code = self.final_exit(o.fail_on);
        if fs::create_dir_all(&self.paths.reports).is_ok() {
            if let Some(path) = &self.state.report_file {
                let mut contents = format!(
                    "=== AUR malware response report ===\nToolkit version: {}\nStarted: {}\n\n",
                    crate::VERSION,
                    Local::now().format("%Y-%m-%d %H:%M:%S")
                );
                contents.push_str(&self.state.log.join("\n"));
                contents.push('\n');
                let _ = crate::config::atomic_write(path, contents.as_bytes());
            }
            let _ = report::write_state(&self.paths.reports, &self.state);
            let _ = report::write_findings(&self.paths.reports, &self.state.findings);
            let atomic = self.paths.list(Campaign::AtomicArch, &self.config);
            let chaos = self.paths.list(Campaign::ChaosRat, &self.config);
            let shai = self.paths.list(Campaign::ShaiHulud, &self.config);
            let openconnect = self.paths.list(Campaign::OpenconnectSso, &self.config);
            let browsh = self.paths.list(Campaign::BrowshLinuxUtils, &self.config);
            let xeactor = self.paths.list(Campaign::Xeactor, &self.config);
            if let Ok(path) = report::write_summary(
                &self.paths.reports,
                &self.state,
                code,
                &[
                    (Campaign::AtomicArch, atomic.as_path()),
                    (Campaign::ChaosRat, chaos.as_path()),
                    (Campaign::ShaiHulud, shai.as_path()),
                    (Campaign::OpenconnectSso, openconnect.as_path()),
                    (Campaign::BrowshLinuxUtils, browsh.as_path()),
                    (Campaign::Xeactor, xeactor.as_path()),
                ],
            ) {
                if o.json {
                    if let Ok(json) = fs::read_to_string(path) {
                        println!("{json}");
                    }
                }
            }
            if o.prune_days > 0 {
                let cutoff = std::time::SystemTime::now()
                    .checked_sub(std::time::Duration::from_secs(o.prune_days * 86_400));
                if let (Some(cutoff), Ok(entries)) = (cutoff, fs::read_dir(&self.paths.reports)) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        let pruneable = path.extension().and_then(|v| v.to_str()) == Some("log")
                            || path.file_name().and_then(|v| v.to_str())
                                == Some("latest-summary.json");
                        if pruneable
                            && fs::metadata(&path)
                                .and_then(|m| m.modified())
                                .is_ok_and(|mtime| mtime <= cutoff)
                        {
                            let _ = fs::remove_file(path);
                        }
                    }
                }
            }
        }
        code
    }
}

#[cfg(test)]
mod tests {
    use super::default_root;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn development_root_is_resolved_from_a_runtime_ancestor() {
        let working = tempfile::tempdir().unwrap();
        fs::create_dir_all(working.path().join("data/lists")).unwrap();
        let nested = working.path().join("src/nested");
        fs::create_dir_all(&nested).unwrap();

        assert_eq!(default_root(Some(nested)), working.path());
    }

    #[test]
    fn existing_directory_without_data_uses_the_installed_root() {
        let working = tempfile::tempdir().unwrap();

        assert_eq!(
            default_root(Some(working.path().to_path_buf())),
            PathBuf::from("/usr/share/aur-response-toolkit")
        );
    }

    #[test]
    fn unavailable_working_directory_uses_the_installed_root() {
        assert_eq!(
            default_root(None),
            PathBuf::from("/usr/share/aur-response-toolkit")
        );
    }
}
