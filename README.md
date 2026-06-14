# atomic-arch-response-toolkit

Fish shell scripts to **detect, triage, and recover** from the June 2026 Arch User Repository (AUR) supply-chain attack — the [Atomic Arch](https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency) campaign that injected `atomic-lockfile`, `js-digest`, and `lockfile-js` into orphaned AUR packages, deploying the [`deps`](https://ioctl.fail/preliminary-analysis-of-aur-malware/) credential stealer and optional eBPF rootkit.

> **Official Arch repos (`[core]`, `[extra]`, `[multilib]`) were not affected.** This toolkit targets AUR packages only.

## TL;DR

Use AUR during **Jun 9–14, 2026**? Clone, scan, act on the exit code:

```fish
git clone https://github.com/bolens/atomic-arch-response-toolkit.git && cd atomic-arch-response-toolkit && chmod +x run.fish scripts/*.fish && fish run.fish
```

- **Exit `0`** — nothing flagged; you're done (or run `fish run.fish --audit` if you want a credential check anyway).
- **Exit `1`** — follow the [recovery flow](#decision-flow) below: remove packages → re-scan → rotate credentials → scrub shell history.

Offline or air-gapped: append `--local` to use the bundled package list.

### Decision flow

```mermaid
flowchart TD
    A[Clone repo & make scripts executable] --> B["fish run.fish"]
    B --> C{Exit code?}

    C -->|0| D([Clean — no action required])
    C -->|1| E["remove-infected.fish --dry-run"]
    E --> F[remove-infected.fish]
    F --> G["run.fish --audit --report"]
    G --> H[rotate-hints.fish]
    H --> I["scrub-history.fish"]
    I --> J([Rotate all credentials the machine had access to])

    D -.->|optional| K["run.fish --audit"]
    K --> L([Credential audit + rotation hints])
```

---

## Quick start

```fish
git clone https://github.com/bolens/atomic-arch-response-toolkit.git
cd atomic-arch-response-toolkit
chmod +x run.fish lint.fish scripts/*.fish

# Full scan (fetches latest infected-package lists from the web)
fish run.fish

# Offline scan (uses bundled data/infected-pkgs.txt)
fish run.fish --local
```

**Exit code `0`** — nothing flagged. **Exit code `1`** — see [Decision flow](#decision-flow) or [If something is found](#if-something-is-found).

---

## Requirements

| Required | Optional |
|----------|----------|
| [Fish shell](https://fishshell.com/) | `paru` or `yay` (AUR helper cache scanning) |
| Arch Linux (or derivative) | `rg` (ripgrep — faster grep; falls back to grep) |
| `pacman`, `curl`, `find`, `comm` | |

---

## How the full scan works

`run.fish` runs seven steps in order. Steps 6–7 run automatically when earlier steps find issues, or when you pass `--audit`.

| Step | Script | What it checks |
|:----:|--------|----------------|
| 1 | `check-infected-pkgs.fish` | Installed packages vs known infected list; HIGH/LOW risk by install date |
| 2 | `scan-aur-window.fish` | All AUR activity during **Jun 9–14, 2026** (catches packages not yet on public lists) |
| 3 | `scan-pacman-timeline.fish` | Known infected packages in `pacman.log` during the window |
| 4 | `scan-malware-artifacts.fish` | `deps` ELF, malicious npm packages, AUR cache hooks, eBPF maps |
| 5 | `scan-hardening.fish` | `npm ignore-scripts`, paru/yay review settings, IOC references |
| 6 | `audit-stolen-credentials.fish` | SSH, git, docker, browsers, chat apps, env files, shell history |
| 7 | `rotate-hints.fish` | Concrete logout and rotation commands |

Infected-package lists are merged from two sources when fetched online:

- [Arch markdown list](https://md.archlinux.org/s/SxbqukK6IA)
- [cscs paste](https://cscs.pastes.sh/raw/aurvulntest20260611.sh)

The merged list is cached in `data/infected-pkgs.txt`.

---

## Usage

### Recommended commands

```fish
# Standard scan — fetch fresh lists, print results
fish run.fish

# Offline / air-gapped — bundled list only
fish run.fish --local

# Always run credential audit + rotation hints, even if clean
fish run.fish --audit

# Save a timestamped report under reports/ plus JSON summary
fish run.fish --report --json

# Quiet mode for timers/CI — minimal stdout, still writes report/json
fish run.fish --local --quiet --report --json
```

### All `run.fish` flags

| Flag | Effect |
|------|--------|
| `--local` | Skip network fetch; use `data/infected-pkgs.txt` |
| `--audit` | Always run steps 6–7 (credential audit + rotation hints) |
| `--report` | Write unified log to `reports/full-scan-*.log` |
| `--json` | Print JSON summary to stdout at end (`reports/latest-summary.json`) |
| `--quiet` | Suppress scan output (report/json still written when requested) |
| `--skip-pkg-check` | Skip step 1 (useful if you already removed packages) |
| `-h`, `--help` | Show usage |

Individual scripts accept `--local`, `--report`, `--quiet`, and `--help` where relevant:

```fish
fish scripts/check-infected-pkgs.fish --local
fish scripts/scan-malware-artifacts.fish
fish scripts/audit-stolen-credentials.fish --help
```

---

## If something is found

Follow this order. Do not skip credential rotation if an infected package was installed during the compromise window.

```fish
# 1. Preview what would be removed
fish scripts/remove-infected.fish --dry-run

# 2. Remove infected packages (interactive confirmation)
fish scripts/remove-infected.fish

# 3. Re-scan with full audit and save a report
fish run.fish --audit --report

# 4. Rotate credentials — follow printed hints
fish scripts/rotate-hints.fish

# 5. After rotating secrets, redact them from fish history
fish scripts/scrub-history.fish --dry-run
fish scripts/scrub-history.fish
```

`remove-infected.fish` flags:

| Flag | Effect |
|------|--------|
| `--dry-run` | Show packages and `pacman -Rns` command without running |
| `--force` | Skip confirmation prompt |
| `pkg ...` | Remove specific packages instead of auto-detecting from the list |

---

## What the malware steals

The `deps` infostealer targets developer credentials: SSH keys, browser cookies, GitHub/npm tokens, Docker registry auth, Discord/Slack/Teams sessions, Vault tokens, shell histories, `.env` files, and more. See the [ioctl.fail analysis](https://ioctl.fail/preliminary-analysis-of-aur-malware/) for full IOCs.

**If any infected package was installed during Jun 9–14, 2026, assume those credentials are compromised and rotate them.**

---

## Automation

### Exit codes

| Code | Meaning |
|:----:|---------|
| `0` | No issues detected |
| `1` | Infected packages, timeline hits, artifacts, or hardening warnings |
| `2` | Invalid CLI arguments |

Example notification hook:

```fish
fish run.fish --local --json || notify-send "AUR incident: issues found"
```

### Weekly systemd timer (optional)

```fish
mkdir -p ~/.config/systemd/user
ln -sf ~/atomic-arch-response-toolkit/systemd/aur-malware-check.service ~/.config/systemd/user/
ln -sf ~/atomic-arch-response-toolkit/systemd/aur-malware-check.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now aur-malware-check.timer
```

Reports land in `reports/` (gitignored). Adjust the clone path in the symlinks if needed.

---

## Development

```fish
# Lint all Fish scripts
fish lint.fish

# Run full test suite
fish tests/run-all.fish
```

### Project layout

```
atomic-arch-response-toolkit/
├── run.fish                      # Main entry point (orchestrator)
├── lint.fish                     # fishcheck linter for all scripts
├── scripts/                      # Scan and recovery scripts
│   ├── check-infected-pkgs.fish
│   ├── scan-aur-window.fish
│   ├── scan-pacman-timeline.fish
│   ├── scan-malware-artifacts.fish
│   ├── scan-hardening.fish
│   ├── audit-stolen-credentials.fish
│   ├── rotate-hints.fish
│   ├── remove-infected.fish
│   └── scrub-history.fish
├── lib/common.fish               # Shared helpers
├── data/infected-pkgs.txt        # Cached merged package list
├── reports/                      # Generated logs (gitignored)
├── tests/
│   ├── run-all.fish              # Full test suite
│   ├── smoke.fish                # Alias for run-all.fish
│   ├── lib/test-utils.fish
│   ├── unit/                     # Pure function tests
│   ├── integration/              # End-to-end script tests
│   └── fixtures/
└── systemd/
    ├── aur-malware-check.service
    └── aur-malware-check.timer
```

---

## References

- [ioctl.fail — preliminary analysis of AUR malware](https://ioctl.fail/preliminary-analysis-of-aur-malware/)
- [Sonatype — Atomic Arch npm campaign](https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency)
- [lenucksi/aur-malware-check](https://github.com/lenucksi/aur-malware-check)
- [Phoronix — 1500+ AUR packages compromised](https://www.phoronix.com/news/Arch-Linux-AUR-400-Compromised)

## License

[MIT](LICENSE)
