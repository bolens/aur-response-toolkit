use crate::config::atomic_write;
use crate::model::{Counters, ScanState};
use crate::VERSION;
use chrono::Local;
use serde::Serialize;
use sha2::{Digest, Sha256};
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
    #[serde(flatten)]
    counters: &'a Counters,
    report_file: String,
    list_sha256: Option<String>,
    chaos_rat_list_sha256: Option<String>,
    findings: BTreeMap<&'a str, Vec<&'a str>>,
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
    fs::read(path)
        .map(|bytes| format!("{:x}", Sha256::digest(bytes)))
        .ok()
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
    atomic_list: &Path,
    chaos_list: &Path,
) -> io::Result<PathBuf> {
    fs::create_dir_all(reports_dir)?;
    let findings = state
        .findings
        .iter()
        .map(|(key, values)| (key.as_str(), values.iter().map(String::as_str).collect()))
        .collect();
    let summary = Summary {
        timestamp: Local::now().format("%Y-%m-%dT%H:%M:%S%z").to_string(),
        version: VERSION,
        host: hostname(),
        exit_code,
        severity: severity(exit_code),
        counters: &state.counters,
        report_file: state
            .report_file
            .as_ref()
            .map(|p| p.display().to_string())
            .unwrap_or_default(),
        list_sha256: sha256(atomic_list),
        chaos_rat_list_sha256: sha256(chaos_list),
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
