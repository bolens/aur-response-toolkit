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
    OpenconnectSso,
    BrowshLinuxUtils,
    XsnowWorm,
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
            "openconnect-sso" => Some(Self::OpenconnectSso),
            "browsh-linux-utils" => Some(Self::BrowshLinuxUtils),
            "xsnow-worm" => Some(Self::XsnowWorm),
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
    OpenconnectSso,
    BrowshLinuxUtils,
    XsnowWorm,
    Xeactor,
}

#[derive(Clone, Copy, Debug, Serialize)]
pub struct CampaignProvenance {
    pub source: &'static str,
    pub retrieved: &'static str,
}

impl Campaign {
    pub const ALL: [Self; 7] = [
        Self::AtomicArch,
        Self::ChaosRat,
        Self::ShaiHulud,
        Self::OpenconnectSso,
        Self::BrowshLinuxUtils,
        Self::XsnowWorm,
        Self::Xeactor,
    ];

    pub const OPTIONAL: [Self; 6] = [
        Self::ChaosRat,
        Self::ShaiHulud,
        Self::OpenconnectSso,
        Self::BrowshLinuxUtils,
        Self::XsnowWorm,
        Self::Xeactor,
    ];

    pub fn from_slug(value: &str) -> Option<Self> {
        Self::ALL
            .into_iter()
            .find(|campaign| campaign.slug() == value)
    }

    pub fn slug(self) -> &'static str {
        match self {
            Self::AtomicArch => "atomic-arch",
            Self::ChaosRat => "chaos-rat",
            Self::ShaiHulud => "shai-hulud",
            Self::OpenconnectSso => "openconnect-sso",
            Self::BrowshLinuxUtils => "browsh-linux-utils",
            Self::XsnowWorm => "xsnow-worm",
            Self::Xeactor => "xeactor",
        }
    }

    pub fn finding_prefix(self) -> &'static str {
        match self {
            Self::AtomicArch => "atomic_arch",
            Self::ChaosRat => "chaos_rat",
            Self::ShaiHulud => "shai_hulud",
            Self::OpenconnectSso => "openconnect_sso",
            Self::BrowshLinuxUtils => "browsh_linux_utils",
            Self::XsnowWorm => "xsnow_worm",
            Self::Xeactor => "xeactor",
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            Self::AtomicArch => "Atomic Arch",
            Self::ChaosRat => "Chaos RAT",
            Self::ShaiHulud => "Shai-Hulud",
            Self::OpenconnectSso => "OpenConnect SSO validator wave",
            Self::BrowshLinuxUtils => "browsh/linux-utils",
            Self::XsnowWorm => "xsnow worm",
            Self::Xeactor => "xeactor",
        }
    }

    pub fn window(self) -> (&'static str, &'static str, &'static str) {
        match self {
            Self::AtomicArch => ("2026-06-09", "2026-06-14", "Jun 9–14, 2026"),
            Self::ChaosRat => ("2025-07-16", "2025-07-18", "Jul 16–18, 2025"),
            Self::ShaiHulud => ("2026-05-16", "2026-05-28", "May 16–28, 2026"),
            Self::OpenconnectSso => ("2026-07-29", "2026-08-02", "Jul 29–Aug 2, 2026"),
            Self::BrowshLinuxUtils => ("2026-05-27", "2026-05-27", "May 27, 2026"),
            Self::XsnowWorm => ("2026-08-23", "2026-08-24", "Aug 23–24, 2026"),
            Self::Xeactor => ("2018-06-07", "2018-07-10", "Jun 7–Jul 10, 2018"),
        }
    }

    pub fn observed_window(self) -> (&'static str, &'static str) {
        match self {
            Self::XsnowWorm => ("2026-08-23", "2026-08-23"),
            _ => {
                let (start, end, _) = self.window();
                (start, end)
            }
        }
    }

    pub fn provenance(self) -> CampaignProvenance {
        match self {
            Self::AtomicArch => CampaignProvenance {
                source: "arch-hedgedoc+cscs-community",
                retrieved: "2026-08-24",
            },
            Self::ChaosRat => CampaignProvenance {
                source: "arch-aur-general+community",
                retrieved: "2026-08-24",
            },
            Self::ShaiHulud => CampaignProvenance {
                source: "arch-aur-general",
                retrieved: "2026-08-24",
            },
            Self::OpenconnectSso => CampaignProvenance {
                source: "gist-firstp1ck:3ea306410a8894d28806a1629c67e825+arch-aur-general",
                retrieved: "2026-08-24",
            },
            Self::BrowshLinuxUtils => CampaignProvenance {
                source: "arch-aur-general",
                retrieved: "2026-08-24",
            },
            Self::XsnowWorm => CampaignProvenance {
                source: "arch-aur-general:FPT525XVV2DL2P437KPHTADV3KJINORN",
                retrieved: "2026-08-24",
            },
            Self::Xeactor => CampaignProvenance {
                source: "public-postmortems",
                retrieved: "2026-08-24",
            },
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
    pub roots_scanned: u64,
    pub roots_unreadable: u64,
    pub files_skipped_oversize: u64,
    pub runtime_adapters_unavailable: u64,
    pub chaos_rat_installed: u64,
    pub chaos_rat_high_risk: u64,
    pub chaos_rat_timeline_hits: u64,
    pub shai_hulud_installed: u64,
    pub shai_hulud_high_risk: u64,
    pub shai_hulud_timeline_hits: u64,
    pub openconnect_sso_installed: u64,
    pub openconnect_sso_high_risk: u64,
    pub openconnect_sso_timeline_hits: u64,
    pub browsh_linux_utils_installed: u64,
    pub browsh_linux_utils_high_risk: u64,
    pub browsh_linux_utils_timeline_hits: u64,
    pub xsnow_worm_installed: u64,
    pub xsnow_worm_high_risk: u64,
    pub xsnow_worm_timeline_hits: u64,
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

#[cfg(test)]
mod tests {
    use super::Campaign;

    #[test]
    fn campaign_registry_slugs_round_trip_and_are_unique() {
        let mut slugs = std::collections::BTreeSet::new();
        for campaign in Campaign::ALL {
            assert_eq!(Campaign::from_slug(campaign.slug()), Some(campaign));
            assert!(slugs.insert(campaign.slug()));
        }
        assert_eq!(Campaign::OPTIONAL.len() + 1, Campaign::ALL.len());
    }
}
