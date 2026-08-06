use crate::model::{FailOn, RunOptions};
use crate::{EXIT_INVALID, VERSION};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CommandKind {
    Full,
    Package(String),
    Timeline(String),
    AurWindow,
    MalwareArtifacts,
    SimilarHeuristics,
    Hardening,
    ListFreshness,
    Audit,
    RotateHints,
    ApplyHardening,
    RemovePackages,
    ScrubHistory,
    ConfigMigrate,
}

#[derive(Debug)]
pub struct Parsed {
    pub kind: CommandKind,
    pub options: RunOptions,
    pub positionals: Vec<String>,
}

pub fn help() -> &'static str {
    "Usage: aur-response [options]
       aur-response scan <packages|timeline> <campaign> [options]
       aur-response scan <aur-window|malware-artifacts|similar-heuristics|hardening> [options]
       aur-response check list-freshness [options]
       aur-response audit [options]
       aur-response recovery <rotate-hints|apply-hardening|remove-packages|scrub-history> [options]
       aur-response config migrate [SOURCE] [DESTINATION]

Exit codes:
  0  clean
  1  compromise indicators
  2  warnings only (hardening, benign unknown AUR packages, optional campaigns)
  3  insufficient data (unreadable logs or missing/empty lists)
  4  invalid arguments

Options:
  --local            Use bundled Atomic Arch list (no network fetch)
  --report           Append output to reports/
  --quiet            Suppress scan output (still writes report/json)
  --quick            Faster scans (narrower artifact search)
  --all-time         Ignore compromise date window for pkg/timeline checks
  --audit            Always run credential audit + rotation hints
  --if-compromised   Only fail credential audit when compromise detected
  --chaos-rat        Also scan Chaos RAT packages (warn-only)
  --shai-hulud       Also scan Mini Shai-Hulud packages (warn-only)
  --xeactor          Also scan 2018 xeactor packages (warn-only)
  --fail-on MODE     Exit policy: all, compromise, chaos-rat, shai-hulud, xeactor, none
  --skip-pkg-check   Skip step 1 package list checks
  --recover          Interactive recovery wizard
  --json             Print JSON summary to stdout at end
  --prune-days N     Delete report files older than N days
  --version          Print toolkit version
  -h, --help         Show this help
"
}

pub fn help_for(kind: &CommandKind) -> String {
    let usage = match kind {
        CommandKind::Full => return help().into(),
        CommandKind::Package(slug) => format!(
            "Usage: aur-response scan packages {slug} [--local] [--all-time] [--report] [--quiet]"
        ),
        CommandKind::Timeline(slug) => format!(
            "Usage: aur-response scan timeline {slug} [--local] [--all-time] [--report] [--quiet]"
        ),
        CommandKind::AurWindow => {
            "Usage: aur-response scan aur-window [--local] [--report] [--quiet] [--quick]".into()
        }
        CommandKind::MalwareArtifacts => {
            "Usage: aur-response scan malware-artifacts [--report] [--quiet] [--quick]".into()
        }
        CommandKind::SimilarHeuristics => {
            "Usage: aur-response scan similar-heuristics [--local] [--report] [--quiet] [--quick]".into()
        }
        CommandKind::Hardening => {
            "Usage: aur-response scan hardening [--report] [--quiet]".into()
        }
        CommandKind::ListFreshness => {
            "Usage: aur-response check list-freshness [--report] [--quiet]".into()
        }
        CommandKind::Audit => {
            "Usage: aur-response audit [--report] [--quiet] [--if-compromised]".into()
        }
        CommandKind::RotateHints => {
            "Usage: aur-response recovery rotate-hints [--report] [--quiet]".into()
        }
        CommandKind::ApplyHardening => {
            "Usage: aur-response recovery apply-hardening [--apply]".into()
        }
        CommandKind::RemovePackages => "Usage: aur-response recovery remove-packages [--list atomic-arch|chaos-rat|shai-hulud|xeactor] [--dry-run] [--force] [--verify] [pkg ...]".into(),
        CommandKind::ScrubHistory => {
            "Usage: aur-response recovery scrub-history [--dry-run] [--all-shells]".into()
        }
        CommandKind::ConfigMigrate => {
            "Usage: aur-response config migrate [SOURCE] [DESTINATION]".into()
        }
    };
    let window = match kind {
        CommandKind::Package(slug) | CommandKind::Timeline(slug) => match slug.as_str() {
            "atomic-arch" => "\nCampaign window: Jun 9–14, 2026",
            "chaos-rat" => "\nCampaign window: Jul 16–18, 2025",
            "shai-hulud" => "\nCampaign window: May 16–17, 2026",
            "xeactor" => "\nCampaign window: Jun 7–Jul 10, 2018",
            _ => "",
        },
        _ => "",
    };
    format!("{usage}\n{window}\n")
}

fn command(args: &[String]) -> Result<(CommandKind, usize), (i32, String)> {
    let value = |index: usize| args.get(index).map(String::as_str);
    let result = match (value(0), value(1), value(2)) {
        (Some("config"), Some("migrate"), _) => (CommandKind::ConfigMigrate, 2),
        (Some("audit"), _, _) => (CommandKind::Audit, 1),
        (Some("check"), Some("list-freshness"), _) => (CommandKind::ListFreshness, 2),
        (Some("scan"), Some("packages"), Some(campaign)) => {
            (CommandKind::Package(campaign.into()), 3)
        }
        (Some("scan"), Some("timeline"), Some(campaign)) => {
            (CommandKind::Timeline(campaign.into()), 3)
        }
        (Some("scan"), Some("aur-window"), _) => (CommandKind::AurWindow, 2),
        (Some("scan"), Some("malware-artifacts"), _) => (CommandKind::MalwareArtifacts, 2),
        (Some("scan"), Some("similar-heuristics"), _) => (CommandKind::SimilarHeuristics, 2),
        (Some("scan"), Some("hardening"), _) => (CommandKind::Hardening, 2),
        (Some("recovery"), Some("rotate-hints"), _) => (CommandKind::RotateHints, 2),
        (Some("recovery"), Some("apply-hardening"), _) => (CommandKind::ApplyHardening, 2),
        (Some("recovery"), Some("remove-packages"), _) => (CommandKind::RemovePackages, 2),
        (Some("recovery"), Some("scrub-history"), _) => (CommandKind::ScrubHistory, 2),
        (Some("scan" | "check" | "recovery" | "config"), _, _) => {
            return Err((EXIT_INVALID, "invalid or incomplete subcommand\n".into()));
        }
        _ => (CommandKind::Full, 0),
    };
    if let CommandKind::Package(campaign) | CommandKind::Timeline(campaign) = &result.0 {
        if !matches!(
            campaign.as_str(),
            "atomic-arch" | "chaos-rat" | "shai-hulud" | "xeactor"
        ) {
            return Err((EXIT_INVALID, format!("unknown campaign: {campaign}\n")));
        }
    }
    Ok(result)
}

pub fn parse(_argv0: &str, args: &[String]) -> Result<Parsed, (i32, String)> {
    let (kind, mut i) = command(args)?;
    let mut options = RunOptions::default();
    let mut positionals = Vec::new();
    while i < args.len() {
        let arg = &args[i];
        match arg.as_str() {
            "-h" | "--help" => return Err((0, help_for(&kind))),
            "--version" => return Err((0, format!("aur-response-toolkit {VERSION}\n"))),
            "--local" => options.local = true,
            "--report" => options.report = true,
            "--audit" => options.audit = true,
            "--quiet" => options.quiet = true,
            "--quick" => options.quick = true,
            "--all-time" => options.all_time = true,
            "--if-compromised" => options.if_compromised = true,
            "--skip-pkg-check" => options.skip_pkg_check = true,
            "--recover" => options.recover = true,
            "--json" => options.json = true,
            "--chaos-rat" => {
                options.campaigns.insert("chaos-rat".into());
            }
            "--shai-hulud" => {
                options.campaigns.insert("shai-hulud".into());
            }
            "--xeactor" => {
                options.campaigns.insert("xeactor".into());
            }
            "--fail-on" => {
                i += 1;
                let Some(value) = args.get(i).and_then(|v| FailOn::parse(v)) else {
                    return Err((EXIT_INVALID, "--fail-on requires a valid mode\n".into()));
                };
                options.fail_on = value;
            }
            "--prune-days" => {
                i += 1;
                options.prune_days = args.get(i).and_then(|v| v.parse().ok()).ok_or_else(|| {
                    (
                        EXIT_INVALID,
                        "--prune-days requires a positive integer\n".into(),
                    )
                })?;
            }
            v if v.starts_with("--fail-on=") => {
                options.fail_on = FailOn::parse(&v[10..]).ok_or_else(|| {
                    (
                        EXIT_INVALID,
                        format!("invalid --fail-on mode: {}\n", &v[10..]),
                    )
                })?;
            }
            v if v.starts_with("--prune-days=") => {
                options.prune_days = v[13..].parse().map_err(|_| {
                    (
                        EXIT_INVALID,
                        "--prune-days requires a positive integer\n".into(),
                    )
                })?;
            }
            v @ ("--dry-run" | "--force" | "--verify" | "--apply" | "--all-shells"
            | "--no-chain") => {
                positionals.push(v.into());
            }
            "--list" => {
                positionals.push(arg.clone());
                i += 1;
                let value = args
                    .get(i)
                    .ok_or_else(|| (EXIT_INVALID, "--list requires a campaign\n".into()))?;
                positionals.push(value.clone());
            }
            v if v.starts_with("--list=") => {
                positionals.push("--list".into());
                positionals.push(v[7..].into());
            }
            v if v.starts_with('-') => {
                return Err((EXIT_INVALID, format!("Unknown option: {v} (see --help)\n")));
            }
            _ => positionals.push(arg.clone()),
        }
        i += 1;
    }
    Ok(Parsed {
        kind,
        options,
        positionals,
    })
}
