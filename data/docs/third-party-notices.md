# Third-party notices

This file satisfies attribution for upstream threat intelligence and list data used by **aur-response-toolkit** (MIT License, Copyright 2026 Michael Bolens).

## What we redistribute

| Artifact | Origin | Notes |
|----------|--------|-------|
| `data/lists/atomic-arch-pkgs.txt` | Arch HedgeDoc + CSCS paste (+ optional user URL) | Snapshot; refreshed on online fetch |
| `data/lists/chaos-rat-pkgs.txt` | Arch aur-general advisory + lenucksi list | Snapshot; merged on fetch |
| `data/lists/shai-hulud-pkgs.txt` | aur-general staff confirmation | Hand-maintained from public advisory |
| `data/lists/xeactor-pkgs.txt` | BleepingComputer + public AUR post-mortems | Hand-maintained factual package names |

We **do not** ship third-party shell scripts (e.g. `aur_check-v2.sh`, CSCS paste) inside this repository.

## What we reference at runtime

Online scans may fetch current lists from URLs configured in `lib/common.fish` / user `config.fish`. SHA256 checksums of fetched content are logged for verification.

## Per-source license status

| Source | License / terms | Our use | Required action |
|--------|-----------------|---------|-----------------|
| **Michael Bolens / this repo** | [MIT](../LICENSE) | — | Include LICENSE in distributions |
| **Arch Linux** (news, aur-general, HedgeDoc) | Public incident data | Package names, advisory text | Link to official URLs in docs |
| **cscs.pastes.sh** (`aurvulntest20260611.sh`) | No explicit license (community gist-style paste) | Parse package names on fetch | Attribution in atomic-arch.md |
| **lenucksi/aur-malware-check** | No SPDX license; README: *"Community tools - no warranty"* | Fetch `chaos_rat_packages.txt`; IOC hash constants credited to ioctl.fail / `iocs.txt` lineage | Attribution; no implied endorsement |
| **ioctl.fail** | Public security write-up | SHA256 IOC constants | URL citation |
| **Sonatype, SafeDep, Socket.dev, BleepingComputer** | Public articles / package pages | Documentation links and context | URL citation |
| **JFrog, Infinum, Cybersecurity Reach, Security Boulevard, Panther, Tenable** | Public Shai-Hulud / npm worm write-ups | `gh-token-monitor` IOC context (cross-ecosystem) | URL citation in shai-hulud.md |
| **Acronis TRU, SC Media, LinuxSecurity, CyberPress, Lemmy (sopuli)** | Public Chaos RAT reporting | Package names, `systemd-initd` IOC, RAT background | URL citation in chaos-rat.md |
| **SecurityWeek, SecurityAffairs, The Register, BetaNews** | Public xeactor (2018) reporting | Package names, versions, ptpb.pw IOCs | URL citation in xeactor.md |
| **tiagorlampert/CHAOS** | MIT License | Upstream RAT referenced in Chaos RAT campaign docs | GitHub URL citation; not redistributed |
| **Privacy Guides / follow-on Chaos RAT reports** | Public reporting | Package names via lenucksi consolidation | Indirect attribution via chaos-rat sources doc |

## Facts vs. expression

Package names, version numbers, file hashes, and security advisory facts are used as indicators of compromise. This is standard threat-intelligence practice and does not reproduce copyrightable expression from upstream detection scripts.

## Changes to upstream lists

Bundled `.txt` files may lag live upstream feeds. Prefer `fish run.fish` (online fetch) for current Arch/CSCS merges, or refresh snapshots when advisories update.

## Contact

To report attribution corrections, open an issue on the toolkit repository with the source URL and requested notice text.
