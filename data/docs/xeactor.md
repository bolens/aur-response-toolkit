# xeactor list sources

Opt-in campaign: orphaned-package takeover with **ptpb.pw** curl\|bash exfil scripts (**Jun 7 – Jul 10, 2018**). Bundled list via `aur_load_xeactor_list`. See also [sources.md](sources.md).

## Package list sources

| Tier | Source | Config |
|------|--------|--------|
| Bundled (default) | `data/lists/xeactor-pkgs.txt` | `AUR_XEACTOR_LIST_FILE` |
| Optional remote | (user URL) | `AUR_XEACTOR_URL` |

No public merged feed exists; list is hand-maintained from post-mortems and aur-general reports. Offline: `--local` + `--xeactor`.

## Confirmed packages

| Package | Version (malicious) | Actor | First malicious activity |
|---------|-------------------|-------|--------------------------|
| `acroread` | 9.5.5-8 | xeactor | 2018-06-07 (orphan takeover + curl hook) |
| `balz` | 1.20-3 | xeactor | same pattern |
| `minergate` | 8.1-2 | xeactor | same pattern |

Malicious **acroread** commit: `b3fec9f2f16703c2dae9e793f75ad6e0d98509bc`.

## References

### Official & community response

| Source | URL | Notes |
|--------|-----|-------|
| aur-general — initial report (Queen Wenceslas) | https://lists.archlinux.org/pipermail/aur-general/2018-July/034151.html | curl\|bash line; commit link |
| aur-general — Eli Schwartz revert + suspend | https://lists.archlinux.org/pipermail/aur-general/2018-July/034152.html | Account suspended same day |
| aur-general — two additional packages fixed | https://lists.archlinux.org/pipermail/aur-general/2018-July/034153.html | `balz`, `minergate` |
| AUR git — malicious acroread commit | https://aur.archlinux.org/cgit/aur.git/commit/?h=acroread&id=b3fec9f2f16703c2dae9e793f75ad6e0d98509bc | PKGBUILD curl to ptpb.pw |

### Technical analysis & post-mortems

| Source | URL | Notes |
|--------|-----|-------|
| BleepingComputer (Jul 2018) | https://www.bleepingcomputer.com/news/security/malware-found-in-arch-linux-aur-package-repository/ | Primary package names/versions; ~x / ~u staging |
| SecurityWeek | https://www.securityweek.com/arch-linux-aur-repository-compromised/ | systemd persistence; metadata collection |
| SecurityAffairs | https://securityaffairs.com/74352/malware/arch-linux-aur-malware.html | Eli Schwartz response; ptpb.pw URLs |
| The Register | https://www.theregister.com/security/2018/07/11/arch-linux-pdf-reader-package-poisoned/1265885 | “compromised.txt” warning theory |
| BetaNews | https://betanews.com/2018/07/11/arch-linux-malware/ | Orphan takeover model |

### Coverage context (AUR trust model)

Giancarlo Razzolini (Arch) noted AUR users must inspect PKGBUILDs — helpers that auto-build without review increase risk. Cited in SecurityWeek / SecurityAffairs coverage above.

## Attack window

**Jun 7 – Jul 10, 2018** — first malicious `acroread` commit through staff revert (~Jul 8–10). Installs outside this window are LOW risk unless `--all-time`.

| Constant | Default |
|----------|---------|
| `AUR_XEACTOR_YEAR` | `2018` |
| `AUR_XEACTOR_WINDOW_LOG_RE` | `2018-(06-(0[7-9]\|[12][0-9]\|30)\|07-(0[1-9]\|10))` |
| `AUR_XEACTOR_WINDOW_LABEL` | `Jun 7–Jul 10, 2018` |

### Timeline

| Date | Event |
|------|-------|
| 2018-06-07 | xeactor modifies orphaned `acroread` PKGBUILD (curl → ptpb.pw) |
| 2018-07-08 | Queen Wenceslas reports on aur-general |
| 2018-07-08 | Eli Schwartz reverts commit, suspends account; fixes `balz`, `minergate` |

## Malware IOCs

Recon-focused dropper; no dedicated hash constants in this toolkit (unlike Atomic Arch ELF IOCs).

| Indicator | Details | Origin |
|-----------|---------|--------|
| Staging URL | `https://ptpb.pw/~x` → `https://ptpb.pw/~u` | BleepingComputer, Eli Schwartz analysis |
| Persistence | systemd timer / periodic restart (attempted) | SecurityWeek |
| Collection | machine ID, CPU, pacman output, `uname -a`, `systemctl list-units` | SecurityWeek, BleepingComputer |
| Marker file | `compromised.txt` in `/` and home dirs (reported) | SecurityWeek, The Register |
| Exfil | Pastebin API / paste upload function (broken in shipped scripts) | Eli Schwartz aur-general notes |

**Toolkit scope:** installed-package check and pacman timeline only. Hunt ptpb.pw references in old AUR build trees manually if investigating historical builds.

## Not the same campaign

| Campaign | Era | Mechanism |
|----------|-----|-----------|
| **xeactor** (this doc) | 2018 | curl\|bash from ptpb.pw in PKGBUILD |
| **Chaos RAT** | Jul 2025 | malicious git patch source → CHAOS RAT |
| **Mini Shai-Hulud AUR** | May 2026 | `crypto-javascript` npm hook |
| **Atomic Arch** | Jun 2026 | `atomic-lockfile` / `js-digest` npm hooks |

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1d | `scripts/check/xeactor-pkgs.fish` | `aur_load_xeactor_list`, `aur_classify_xeactor_pkg` |
| 3d | `scripts/scan/xeactor-timeline.fish` | `aur_collect_xeactor_window_alpm_events*` |
| — | `scripts/recovery/remove-packages.fish` | `--list xeactor` |

| Piece | Location |
|-------|----------|
| Enable | `--xeactor`, `AUR_ENABLE_XEACTOR`, `aur_xeactor_enabled` |
| JSON | `xeactor_*` in `lib/reports.fish` |
| Exit policy | `--fail-on xeactor` |

Legacy config aliases: `AUR_ENABLE_LEGACY_2018`, `AUR_LEGACY_2018_*` → xeactor names in `lib/common.fish`.

## Integrity

Bundled list only by default. Optional `AUR_XEACTOR_URL` fetch logs SHA256 via `aur_fetch_source_with_sha`. No Arch HedgeDoc merge.

## Maintenance

- Add packages only when public advisories confirm the same **xeactor** actor, **ptpb.pw** staging, and 2018 window.
- Optional `AUR_XEACTOR_URL` if a community plain-text list appears.

## License & attribution

Factual package names and versions from public post-mortems (BleepingComputer, aur-general). No third-party list file fetched by default.

See [third-party-notices.md](third-party-notices.md).
