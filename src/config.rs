use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use crate::model::Campaign;

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(default)]
pub struct Config {
    pub dev_root: Option<PathBuf>,
    pub deps_search_paths: Vec<PathBuf>,
    pub helper_cache_roots: Vec<PathBuf>,
    pub makepkg_build_dirs: Vec<PathBuf>,
    pub pamac_build_globs: Vec<String>,
    pub pacman_log_dir: Option<PathBuf>,
    pub pacman_local_dir: Option<PathBuf>,
    pub history_helpers: Option<String>,
    pub atomic_arch_list_file: Option<PathBuf>,
    pub list_max_age_days: Option<u64>,
    pub list_url_arch: Option<String>,
    pub list_url_cscs: Option<String>,
    pub list_url_extra: Option<String>,
    pub similar_heuristics_pattern: Option<String>,
    pub similar_heuristics_noise_pattern: Option<String>,
    pub enable_chaos_rat: Option<bool>,
    pub chaos_rat_url_arch: Option<String>,
    pub chaos_rat_url_community: Option<String>,
    pub chaos_rat_url_extra: Option<String>,
    pub chaos_rat_list_file: Option<PathBuf>,
    pub enable_shai_hulud: Option<bool>,
    pub shai_hulud_list_file: Option<PathBuf>,
    pub shai_hulud_url: Option<String>,
    pub shai_hulud_window_log_re: Option<String>,
    pub shai_hulud_window_install_days_re: Option<String>,
    pub shai_hulud_window_install_month: Option<String>,
    pub shai_hulud_window_label: Option<String>,
    pub enable_openconnect_sso: Option<bool>,
    pub openconnect_sso_list_file: Option<PathBuf>,
    pub openconnect_sso_url: Option<String>,
    pub enable_browsh_linux_utils: Option<bool>,
    pub browsh_linux_utils_list_file: Option<PathBuf>,
    pub browsh_linux_utils_url: Option<String>,
    pub enable_xsnow_worm: Option<bool>,
    pub xsnow_worm_list_file: Option<PathBuf>,
    pub xsnow_worm_url: Option<String>,
    pub enable_xeactor: Option<bool>,
    pub xeactor_list_file: Option<PathBuf>,
    pub xeactor_url: Option<String>,
    pub xeactor_window_log_re: Option<String>,
    pub xeactor_window_label: Option<String>,
    pub reports_dir: Option<PathBuf>,
}

impl Config {
    pub fn campaign_enabled(&self, campaign: Campaign) -> bool {
        match campaign {
            Campaign::AtomicArch => true,
            Campaign::ChaosRat => self.enable_chaos_rat == Some(true),
            Campaign::ShaiHulud => self.enable_shai_hulud == Some(true),
            Campaign::OpenconnectSso => self.enable_openconnect_sso == Some(true),
            Campaign::BrowshLinuxUtils => self.enable_browsh_linux_utils == Some(true),
            Campaign::XsnowWorm => self.enable_xsnow_worm == Some(true),
            Campaign::Xeactor => self.enable_xeactor == Some(true),
        }
    }

    pub fn campaign_list_file(&self, campaign: Campaign) -> Option<PathBuf> {
        match campaign {
            Campaign::AtomicArch => self.atomic_arch_list_file.clone(),
            Campaign::ChaosRat => self.chaos_rat_list_file.clone(),
            Campaign::ShaiHulud => self.shai_hulud_list_file.clone(),
            Campaign::OpenconnectSso => self.openconnect_sso_list_file.clone(),
            Campaign::BrowshLinuxUtils => self.browsh_linux_utils_list_file.clone(),
            Campaign::XsnowWorm => self.xsnow_worm_list_file.clone(),
            Campaign::Xeactor => self.xeactor_list_file.clone(),
        }
    }
}

#[derive(Debug)]
pub struct LoadedConfig {
    pub config: Config,
}

fn env_bool(key: &str) -> Option<bool> {
    env::var(key)
        .ok()
        .map(|value| matches!(value.as_str(), "1" | "true" | "yes"))
}

fn apply_environment(config: &mut Config) {
    macro_rules! path {
        ($field:ident, $key:literal) => {
            if let Some(value) = env::var_os($key) {
                config.$field = Some(PathBuf::from(value));
            }
        };
    }
    macro_rules! string {
        ($field:ident, $key:literal) => {
            if let Ok(value) = env::var($key) {
                config.$field = Some(value);
            }
        };
    }
    path!(dev_root, "AUR_DEV_ROOT");
    path!(pacman_log_dir, "AUR_PACMAN_LOG_DIR");
    path!(pacman_local_dir, "AUR_PACMAN_LOCAL_DIR");
    path!(atomic_arch_list_file, "AUR_ATOMIC_ARCH_LIST_FILE");
    path!(chaos_rat_list_file, "AUR_CHAOS_RAT_LIST_FILE");
    path!(shai_hulud_list_file, "AUR_SHAI_HULUD_LIST_FILE");
    path!(openconnect_sso_list_file, "AUR_OPENCONNECT_SSO_LIST_FILE");
    path!(
        browsh_linux_utils_list_file,
        "AUR_BROWSH_LINUX_UTILS_LIST_FILE"
    );
    path!(xeactor_list_file, "AUR_XEACTOR_LIST_FILE");
    path!(xsnow_worm_list_file, "AUR_XSNOW_WORM_LIST_FILE");
    path!(reports_dir, "AUR_REPORTS_DIR");
    string!(history_helpers, "AUR_HISTORY_HELPERS");
    string!(list_url_arch, "AUR_LIST_URL_ARCH");
    string!(list_url_cscs, "AUR_LIST_URL_CSCS");
    string!(list_url_extra, "AUR_LIST_URL_EXTRA");
    string!(similar_heuristics_pattern, "AUR_SIMILAR_HEURISTICS_PATTERN");
    string!(chaos_rat_url_arch, "AUR_CHAOS_RAT_URL_ARCH");
    string!(chaos_rat_url_community, "AUR_CHAOS_RAT_URL_COMMUNITY");
    string!(chaos_rat_url_extra, "AUR_CHAOS_RAT_URL_EXTRA");
    string!(shai_hulud_url, "AUR_SHAI_HULUD_URL");
    string!(shai_hulud_window_log_re, "AUR_SHAI_HULUD_WINDOW_LOG_RE");
    string!(
        shai_hulud_window_install_days_re,
        "AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE"
    );
    string!(
        shai_hulud_window_install_month,
        "AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH"
    );
    string!(shai_hulud_window_label, "AUR_SHAI_HULUD_WINDOW_LABEL");
    string!(openconnect_sso_url, "AUR_OPENCONNECT_SSO_URL");
    string!(browsh_linux_utils_url, "AUR_BROWSH_LINUX_UTILS_URL");
    string!(xeactor_url, "AUR_XEACTOR_URL");
    string!(xsnow_worm_url, "AUR_XSNOW_WORM_URL");
    string!(xeactor_window_log_re, "AUR_XEACTOR_WINDOW_LOG_RE");
    string!(xeactor_window_label, "AUR_XEACTOR_WINDOW_LABEL");
    if let Ok(value) = env::var("AUR_LIST_MAX_AGE_DAYS") {
        config.list_max_age_days = value.parse().ok();
    }
    config.enable_chaos_rat = env_bool("AUR_ENABLE_CHAOS_RAT").or(config.enable_chaos_rat);
    config.enable_shai_hulud = env_bool("AUR_ENABLE_SHAI_HULUD").or(config.enable_shai_hulud);
    config.enable_openconnect_sso =
        env_bool("AUR_ENABLE_OPENCONNECT_SSO").or(config.enable_openconnect_sso);
    config.enable_browsh_linux_utils =
        env_bool("AUR_ENABLE_BROWSH_LINUX_UTILS").or(config.enable_browsh_linux_utils);
    config.enable_xeactor = env_bool("AUR_ENABLE_XEACTOR").or(config.enable_xeactor);
    config.enable_xsnow_worm = env_bool("AUR_ENABLE_XSNOW_WORM").or(config.enable_xsnow_worm);
    if let Some(value) = env::var_os("AUR_DEPS_SEARCH_PATHS") {
        config.deps_search_paths = env::split_paths(&value).collect();
    }
    if let Some(value) = env::var_os("AUR_HELPER_CACHE_ROOTS") {
        config.helper_cache_roots = env::split_paths(&value).collect();
    }
}

fn home() -> PathBuf {
    env::var_os("HOME").map(PathBuf::from).unwrap_or_default()
}

pub fn config_dir() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".config"))
        .join("aur-response")
}

fn expand_home(value: &str) -> String {
    let home = home().to_string_lossy().into_owned();
    value
        .replace("${HOME}", &home)
        .replace("$HOME", &home)
        .replace('~', &home)
}

fn shell_words(line: &str) -> Result<Vec<String>, String> {
    let mut words = Vec::new();
    let mut current = String::new();
    let mut quote = None;
    let mut escaped = false;
    for ch in line.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }
        if ch == '\\' && quote != Some('\'') {
            escaped = true;
            continue;
        }
        if let Some(q) = quote {
            if ch == q {
                quote = None;
            } else {
                current.push(ch);
            }
        } else {
            match ch {
                '\'' | '"' => quote = Some(ch),
                ' ' | '\t' if !current.is_empty() => {
                    words.push(std::mem::take(&mut current));
                }
                ' ' | '\t' => {}
                '#' => break,
                ';' | '|' | '&' | '(' | ')' => {
                    return Err("executable Fish syntax is unsupported".into())
                }
                _ => current.push(ch),
            }
        }
    }
    if quote.is_some() {
        return Err("unterminated quote".into());
    }
    if !current.is_empty() {
        words.push(current);
    }
    Ok(words)
}

pub fn parse_legacy(input: &str) -> (BTreeMap<String, Vec<String>>, Vec<String>) {
    let mut values = BTreeMap::new();
    let mut warnings = Vec::new();
    for (idx, raw) in input.lines().enumerate() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        match shell_words(line) {
            Ok(words) if words.len() >= 4 && words[0] == "set" && words[1] == "-g" => {
                values.insert(
                    words[2].clone(),
                    words[3..].iter().map(|v| expand_home(v)).collect(),
                );
            }
            Ok(_) => warnings.push(format!(
                "config.fish:{}: expected `set -g NAME VALUE`",
                idx + 1
            )),
            Err(reason) => warnings.push(format!("config.fish:{}: {reason}", idx + 1)),
        }
    }
    (values, warnings)
}

fn bool_value(values: &BTreeMap<String, Vec<String>>, key: &str) -> Option<bool> {
    values
        .get(key)?
        .first()
        .map(|v| matches!(v.as_str(), "1" | "true" | "yes"))
}

fn first(values: &BTreeMap<String, Vec<String>>, key: &str) -> Option<String> {
    values.get(key)?.first().cloned()
}

fn legacy_config(values: &BTreeMap<String, Vec<String>>) -> Config {
    Config {
        dev_root: first(values, "AUR_DEV_ROOT").map(PathBuf::from),
        deps_search_paths: values
            .get("AUR_DEPS_SEARCH_PATHS")
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(PathBuf::from)
            .collect(),
        helper_cache_roots: values
            .get("AUR_HELPER_CACHE_ROOTS")
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(PathBuf::from)
            .collect(),
        makepkg_build_dirs: values
            .get("AUR_MAKEPKG_BUILD_DIRS")
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(PathBuf::from)
            .collect(),
        pamac_build_globs: values
            .get("AUR_PAMAC_BUILD_GLOBS")
            .cloned()
            .unwrap_or_default(),
        pacman_log_dir: first(values, "AUR_PACMAN_LOG_DIR").map(PathBuf::from),
        pacman_local_dir: first(values, "AUR_PACMAN_LOCAL_DIR").map(PathBuf::from),
        history_helpers: first(values, "AUR_HISTORY_HELPERS"),
        atomic_arch_list_file: first(values, "AUR_ATOMIC_ARCH_LIST_FILE").map(PathBuf::from),
        list_max_age_days: first(values, "AUR_LIST_MAX_AGE_DAYS").and_then(|v| v.parse().ok()),
        list_url_arch: first(values, "AUR_LIST_URL_ARCH"),
        list_url_cscs: first(values, "AUR_LIST_URL_CSCS"),
        list_url_extra: first(values, "AUR_LIST_URL_EXTRA"),
        similar_heuristics_pattern: first(values, "AUR_SIMILAR_HEURISTICS_PATTERN"),
        similar_heuristics_noise_pattern: first(values, "AUR_SIMILAR_HEURISTICS_NOISE_PATTERN"),
        enable_chaos_rat: bool_value(values, "AUR_ENABLE_CHAOS_RAT"),
        chaos_rat_url_arch: first(values, "AUR_CHAOS_RAT_URL_ARCH"),
        chaos_rat_url_community: first(values, "AUR_CHAOS_RAT_URL_COMMUNITY"),
        chaos_rat_url_extra: first(values, "AUR_CHAOS_RAT_URL_EXTRA"),
        chaos_rat_list_file: first(values, "AUR_CHAOS_RAT_LIST_FILE").map(PathBuf::from),
        enable_shai_hulud: bool_value(values, "AUR_ENABLE_SHAI_HULUD"),
        shai_hulud_list_file: first(values, "AUR_SHAI_HULUD_LIST_FILE").map(PathBuf::from),
        shai_hulud_url: first(values, "AUR_SHAI_HULUD_URL"),
        shai_hulud_window_log_re: first(values, "AUR_SHAI_HULUD_WINDOW_LOG_RE"),
        shai_hulud_window_install_days_re: first(values, "AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE"),
        shai_hulud_window_install_month: first(values, "AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH"),
        shai_hulud_window_label: first(values, "AUR_SHAI_HULUD_WINDOW_LABEL"),
        enable_openconnect_sso: bool_value(values, "AUR_ENABLE_OPENCONNECT_SSO"),
        openconnect_sso_list_file: first(values, "AUR_OPENCONNECT_SSO_LIST_FILE")
            .map(PathBuf::from),
        openconnect_sso_url: first(values, "AUR_OPENCONNECT_SSO_URL"),
        enable_browsh_linux_utils: bool_value(values, "AUR_ENABLE_BROWSH_LINUX_UTILS"),
        browsh_linux_utils_list_file: first(values, "AUR_BROWSH_LINUX_UTILS_LIST_FILE")
            .map(PathBuf::from),
        browsh_linux_utils_url: first(values, "AUR_BROWSH_LINUX_UTILS_URL"),
        enable_xsnow_worm: bool_value(values, "AUR_ENABLE_XSNOW_WORM"),
        xsnow_worm_list_file: first(values, "AUR_XSNOW_WORM_LIST_FILE").map(PathBuf::from),
        xsnow_worm_url: first(values, "AUR_XSNOW_WORM_URL"),
        enable_xeactor: bool_value(values, "AUR_ENABLE_XEACTOR"),
        xeactor_list_file: first(values, "AUR_XEACTOR_LIST_FILE").map(PathBuf::from),
        xeactor_url: first(values, "AUR_XEACTOR_URL"),
        xeactor_window_log_re: first(values, "AUR_XEACTOR_WINDOW_LOG_RE"),
        xeactor_window_label: first(values, "AUR_XEACTOR_WINDOW_LABEL"),
        reports_dir: None,
    }
}

pub fn load() -> Result<LoadedConfig, String> {
    load_from_dir(&config_dir())
}

pub fn load_from_dir(dir: &Path) -> Result<LoadedConfig, String> {
    let toml_path = dir.join("config.toml");
    if toml_path.exists() {
        let input =
            fs::read_to_string(&toml_path).map_err(|e| format!("{}: {e}", toml_path.display()))?;
        let mut config =
            toml::from_str(&input).map_err(|e| format!("{}: {e}", toml_path.display()))?;
        apply_environment(&mut config);
        return Ok(LoadedConfig { config });
    }
    let mut config = Config::default();
    apply_environment(&mut config);
    Ok(LoadedConfig { config })
}

pub fn migrate(source: &Path, destination: &Path) -> Result<Vec<String>, String> {
    let input = fs::read_to_string(source).map_err(|e| format!("{}: {e}", source.display()))?;
    let (values, warnings) = parse_legacy(&input);
    if !warnings.is_empty() {
        return Err(warnings.join("\n"));
    }
    let encoded = toml::to_string_pretty(&legacy_config(&values)).map_err(|e| e.to_string())?;
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    atomic_write(destination, encoded.as_bytes()).map_err(|e| e.to_string())?;
    Ok(warnings)
}

pub fn atomic_write(path: &Path, data: &[u8]) -> io::Result<()> {
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    let tmp = parent.join(format!(
        ".{}.tmp-{}",
        path.file_name().unwrap_or_default().to_string_lossy(),
        std::process::id()
    ));
    fs::write(&tmp, data)?;
    fs::rename(tmp, path)
}
