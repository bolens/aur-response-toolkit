use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum FailOn {
    #[default]
    All,
    Compromise,
    ChaosRat,
    ShaiHulud,
    Xeactor,
    None,
}

impl FailOn {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "all" => Some(Self::All),
            "compromise" => Some(Self::Compromise),
            "chaos-rat" => Some(Self::ChaosRat),
            "shai-hulud" => Some(Self::ShaiHulud),
            "xeactor" => Some(Self::Xeactor),
            "none" => Some(Self::None),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Campaign {
    AtomicArch,
    ChaosRat,
    ShaiHulud,
    Xeactor,
}

impl Campaign {
    pub fn slug(self) -> &'static str {
        match self {
            Self::AtomicArch => "atomic-arch",
            Self::ChaosRat => "chaos-rat",
            Self::ShaiHulud => "shai-hulud",
            Self::Xeactor => "xeactor",
        }
    }

    pub fn finding_prefix(self) -> &'static str {
        match self {
            Self::AtomicArch => "atomic_arch",
            Self::ChaosRat => "chaos_rat",
            Self::ShaiHulud => "shai_hulud",
            Self::Xeactor => "xeactor",
        }
    }

    pub fn window(self) -> (&'static str, &'static str, &'static str) {
        match self {
            Self::AtomicArch => ("2026-06-09", "2026-06-14", "Jun 9–14, 2026"),
            Self::ChaosRat => ("2025-07-16", "2025-07-18", "Jul 16–18, 2025"),
            Self::ShaiHulud => ("2026-05-16", "2026-05-17", "May 16–17, 2026"),
            Self::Xeactor => ("2018-06-07", "2018-07-10", "Jun 7–Jul 10, 2018"),
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct RunOptions {
    pub local: bool,
    pub report: bool,
    pub audit: bool,
    pub quiet: bool,
    pub quick: bool,
    pub all_time: bool,
    pub if_compromised: bool,
    pub skip_pkg_check: bool,
    pub recover: bool,
    pub json: bool,
    pub campaigns: BTreeSet<String>,
    pub fail_on: FailOn,
    pub prune_days: u64,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Counters {
    pub atomic_arch_installed: u64,
    pub atomic_arch_high_risk: u64,
    pub atomic_arch_timeline_hits: u64,
    pub atomic_arch_timeline_repeat_updates: u64,
    pub window_aur_pkgs: u64,
    pub artifact_critical: u64,
    pub credential_exposed: u64,
    pub hardening_warn: u64,
    pub list_added: u64,
    pub list_removed: u64,
    pub insufficient_data: u64,
    pub runtime_iocs: u64,
    pub chaos_rat_installed: u64,
    pub chaos_rat_high_risk: u64,
    pub chaos_rat_timeline_hits: u64,
    pub shai_hulud_installed: u64,
    pub shai_hulud_high_risk: u64,
    pub shai_hulud_timeline_hits: u64,
    pub xeactor_installed: u64,
    pub xeactor_high_risk: u64,
    pub xeactor_timeline_hits: u64,
}

#[derive(Clone, Debug, Default)]
pub struct ScanState {
    pub counters: Counters,
    pub findings: BTreeMap<String, BTreeSet<String>>,
    pub compromise: bool,
    pub warning: bool,
    pub insufficient: bool,
    pub optional_warnings: BTreeSet<String>,
    pub report_file: Option<PathBuf>,
    pub log: Vec<String>,
}

impl ScanState {
    pub fn finding(&mut self, category: impl Into<String>, item: impl Into<String>) {
        self.findings
            .entry(category.into())
            .or_default()
            .insert(item.into());
    }

    pub fn log(&mut self, quiet: bool, line: impl Into<String>) {
        let line = line.into();
        if !quiet {
            println!("{line}");
        }
        self.log.push(line);
    }
}
