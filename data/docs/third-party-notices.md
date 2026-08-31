# Third-party notices

This file attributes the upstream threat intelligence and list data used by
**aur-response-toolkit**. The toolkit is available under the MIT License and is
Copyright 2026 Michael Bolens.

## What we redistribute

| Artifact | Origin | Notes |
|----------|--------|-------|
| `data/lists/atomic-arch-pkgs.txt` | Arch HedgeDoc + CSCS paste (+ optional user URL) | Snapshot; refreshed on online fetch |
| `data/lists/chaos-rat-pkgs.txt` | Arch aur-general advisory + lenucksi list | Snapshot; merged on fetch |
| `data/lists/shai-hulud-pkgs.txt` | aur-general staff confirmation | Hand-maintained from public advisory |
| `data/lists/openconnect-sso-pkgs.txt` | Arch aur-general + Firstp1ck static campaign review | Confirmed package names only; candidate/false-positive tables excluded |
| `data/lists/xeactor-pkgs.txt` | BleepingComputer + public AUR post-mortems | Hand-maintained factual package names |
| `data/lists/xsnow-worm-pkgs.txt` | Arch aur-general staff-confirmed incident | Hand-maintained factual package names |

This repository does not ship third-party shell scripts such as
`aur_check-v2.sh` or the CSCS paste.

## What we reference at runtime

Online scans can fetch current lists from URLs configured in `src/config.rs`,
`src/engine.rs`, or the user's `config.toml`. The toolkit logs SHA256 checksums
of fetched content for verification.

## Per-source license status

| Source | License / terms | Our use | Required action |
|--------|-----------------|---------|-----------------|
| **Michael Bolens and this repository** | [MIT](../../LICENSE) | Not applicable | Include LICENSE in distributions |
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

The toolkit uses package names, version numbers, file hashes, and advisory facts
as indicators of compromise. It does not copy source code or other protected
expression from upstream detection scripts.

## Changes to upstream lists

Bundled `.txt` files may lag behind upstream feeds. Use an online
`aur-response` scan for current Arch and CSCS merges. Refresh bundled snapshots
when advisories change.

## Contact

To correct an attribution, open an issue with the source URL and the requested
notice text.
