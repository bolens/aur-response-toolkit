use crate::config::atomic_write;
use crate::inspection::{self, Bounded};
use crate::integrity;
use crate::ioc;
use crate::model::{Campaign, Counters, ScanState};
use crate::VERSION;
use chrono::Local;
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Serialize)]
pub struct Summary<'a> {
    timestamp: String,
    version: &'static str,
    host: String,
    exit_code: i32,
    severity: &'static str,
    ioc_registry_version: &'static str,
    ioc_registry_sha256: String,
    coverage_complete: bool,
    #[serde(flatten)]
    counters: &'a Counters,
    report_file: String,
    list_sha256: Option<String>,
    chaos_rat_list_sha256: Option<String>,
    shai_hulud_list_sha256: Option<String>,
    openconnect_sso_list_sha256: Option<String>,
    openconnect_sso_list_source: &'static str,
    openconnect_sso_list_retrieved: &'static str,
    browsh_linux_utils_list_sha256: Option<String>,
    xsnow_worm_list_sha256: Option<String>,
    xeactor_list_sha256: Option<String>,
    campaigns: Vec<CampaignMetadata>,
    findings: BTreeMap<&'a str, Vec<&'a str>>,
}

#[derive(Serialize)]
struct CampaignMetadata {
    slug: &'static str,
    source: &'static str,
    retrieved: &'static str,
    observed_start: &'static str,
    observed_end: &'static str,
    scan_start: &'static str,
    scan_end: &'static str,
    list_sha256: Option<String>,
    expected_list_sha256: Option<String>,
}

pub fn severity(code: i32) -> &'static str {
    match code {
        1 => "critical",
        2 => "warning",
        3 => "insufficient",
        _ => "clean",
    }
}

pub fn sha256(path: &Path) -> Option<String> {
    match inspection::sha256(path, inspection::MAX_ARTIFACT_BYTES).ok()? {
        Bounded::Value(hash) => Some(hash),
        Bounded::Oversize => None,
    }
}

fn hostname() -> String {
    std::env::var("HOSTNAME").unwrap_or_else(|_| {
        fs::read_to_string("/etc/hostname")
            .map(|v| v.trim().to_owned())
            .unwrap_or_default()
    })
}

pub fn write_summary(
    reports_dir: &Path,
    state: &ScanState,
    exit_code: i32,
    lists: &[(Campaign, &Path)],
) -> io::Result<PathBuf> {
    fs::create_dir_all(reports_dir)?;
    let findings = state
        .findings
        .iter()
        .map(|(key, values)| (key.as_str(), values.iter().map(String::as_str).collect()))
        .collect();
    let list_hash = |campaign| {
        lists
            .iter()
            .find(|(candidate, _)| *candidate == campaign)
            .and_then(|(_, path)| sha256(path))
    };
    let manifest = lists
        .iter()
        .find_map(|(_, path)| path.parent()?.parent())
        .and_then(|data| integrity::load(&data.join("integrity.toml")).ok());
    let campaigns = Campaign::ALL
        .into_iter()
        .map(|campaign| {
            let provenance = campaign.provenance();
            let (observed_start, observed_end) = campaign.observed_window();
            let (scan_start, scan_end, _) = campaign.window();
            CampaignMetadata {
                slug: campaign.slug(),
                source: provenance.source,
                retrieved: provenance.retrieved,
                observed_start,
                observed_end,
                scan_start,
                scan_end,
                list_sha256: list_hash(campaign),
                expected_list_sha256: manifest
                    .as_ref()
                    .and_then(|manifest| manifest.lists.get(campaign.slug()).cloned()),
            }
        })
        .collect();
    let summary = Summary {
        timestamp: Local::now().format("%Y-%m-%dT%H:%M:%S%z").to_string(),
        version: VERSION,
        host: hostname(),
        exit_code,
        severity: severity(exit_code),
        ioc_registry_version: ioc::IOC_REGISTRY_VERSION,
        ioc_registry_sha256: ioc::registry_sha256(),
        coverage_complete: state.counters.roots_unreadable == 0
            && state.counters.files_skipped_oversize == 0
            && state.counters.runtime_adapters_unavailable == 0,
        counters: &state.counters,
        report_file: state
            .report_file
            .as_ref()
            .map(|p| p.display().to_string())
            .unwrap_or_default(),
        list_sha256: list_hash(Campaign::AtomicArch),
        chaos_rat_list_sha256: list_hash(Campaign::ChaosRat),
        shai_hulud_list_sha256: list_hash(Campaign::ShaiHulud),
        openconnect_sso_list_sha256: list_hash(Campaign::OpenconnectSso),
        openconnect_sso_list_source:
            "gist-firstp1ck:3ea306410a8894d28806a1629c67e825+arch-aur-general",
        openconnect_sso_list_retrieved: "2026-08-24",
        browsh_linux_utils_list_sha256: list_hash(Campaign::BrowshLinuxUtils),
        xsnow_worm_list_sha256: list_hash(Campaign::XsnowWorm),
        xeactor_list_sha256: list_hash(Campaign::Xeactor),
        campaigns,
        findings,
    };
    let bytes = serde_json::to_vec_pretty(&summary)?;
    let path = reports_dir.join("latest-summary.json");
    atomic_write(&path, &bytes)?;
    atomic_write(&reports_dir.join(".scan-findings.json"), &bytes)?;
    Ok(path)
}

pub fn write_findings(
    reports_dir: &Path,
    findings: &BTreeMap<String, BTreeSet<String>>,
) -> io::Result<()> {
    let mut text = String::new();
    for (category, items) in findings {
        for item in items {
            text.push_str(category);
            text.push('\t');
            text.push_str(item);
            text.push('\n');
        }
    }
    atomic_write(&reports_dir.join(".scan-findings.list"), text.as_bytes())
}

pub fn write_state(reports_dir: &Path, state: &ScanState) -> io::Result<()> {
    let mut values = serde_json::to_value(&state.counters)
        .unwrap()
        .as_object()
        .unwrap()
        .iter()
        .map(|(k, v)| (k.clone(), v.as_u64().unwrap_or_default()))
        .collect::<BTreeMap<_, _>>();
    values.insert("compromised".into(), u64::from(state.compromise));
    let text = values
        .into_iter()
        .map(|(k, v)| format!("{k}={v}\n"))
        .collect::<String>();
    atomic_write(&reports_dir.join(".scan-state"), text.as_bytes())
}
