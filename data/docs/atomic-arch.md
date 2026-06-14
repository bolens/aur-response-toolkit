# Atomic Arch list & IOC sources

Primary campaign: **atomic-lockfile**, **lockfile-js**, and **js-digest** npm/bun hooks in orphaned AUR packages (June 2026).

## Package list sources

Merged online by `aur_load_atomic_arch_list` (`lib/common.fish`). Cached at `data/lists/atomic-arch-pkgs.txt`.

| Tier | URL | Config override |
|------|-----|-----------------|
| Arch HedgeDoc (staff/community) | https://md.archlinux.org/s/SxbqukK6IA | `AUR_LIST_URL_ARCH` |
| commonsourcecs detection script | https://cscs.pastes.sh/raw/aurvulntest20260611.sh | `AUR_LIST_URL_CSCS` |
| Optional third source | (user URL) | `AUR_LIST_URL_EXTRA` |

Offline: `--local` uses bundled `data/lists/atomic-arch-pkgs.txt`.

## References

### Official & community response

| Source | URL |
|--------|-----|
| Arch Linux — Active AUR malicious packages incident | https://archlinux.org/news/active-aur-malicious-packages-incident/ |
| aur-general — master thread | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/FGXPCB3ZVCJIV7FX323SBAX2JHYB7ZS4/ |
| aur-general — HedgeDoc package list | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/FCH7TT6IOVT7D477JKSVJALBKADAARSW/ |
| aur-general — first confirmed report (ALVR) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/2LGBF2AZBPVCCY4VTN6DOVUNNBURFJ2J/ |
| aur-general — first gnome-randr-rust report | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/L2JXQNYBGWOQQQXDEPEAICBHKFEFANUC/ |
| aur-general — js-digest / bun wave | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/LB6TBHDXLQRPR4UVIQULCI6MZ77XYLL2/ |

### Technical analysis

| Source | URL |
|--------|-----|
| ioctl.fail — preliminary analysis | https://ioctl.fail/preliminary-analysis-of-aur-malware/ |
| Sonatype — Atomic Arch npm campaign | https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency |
| SafeDep — Atomic Arch campaign intel | https://safedep.io/ti/campaigns/atomic-arch |
| Socket.dev — atomic-lockfile | https://socket.dev/npm/package/atomic-lockfile |
| Socket.dev — js-digest | https://socket.dev/npm/package/js-digest |

### Package lists & detection tools

| Source | URL |
|--------|-----|
| Arch HedgeDoc — merged list | https://md.archlinux.org/s/SxbqukK6IA |
| cscs — detection script / list | https://cscs.pastes.sh/raw/aurvulntest20260611.sh |
| lenucksi/aur-malware-check | https://github.com/lenucksi/aur-malware-check |

Community script lineage (Kidev, BrianCArnold, commonsourcecs, Kacper-Kondracki, quantenProjects): see upstream [README § Sources](https://github.com/lenucksi/aur-malware-check/blob/master/README.md#sources).

### Coverage

| Source | URL |
|--------|-----|
| IFIN — community triage thread | https://discourse.ifin.network/t/400-aur-packages-compromised-with-infostealer-and-rootkit/577 |
| BleepingComputer — 400+ packages | https://www.bleepingcomputer.com/news/security/over-400-arch-linux-packages-compromised-to-push-rootkit-infostealer/ |
| Phoronix — 1,500+ packages | https://www.phoronix.com/news/Arch-Linux-AUR-More-Than-1500 |

## Attack window

**Jun 9–14, 2026** — install date and pacman.log triage for HIGH vs LOW risk.

| Constant | Default |
|----------|---------|
| `AUR_WINDOW_LOG_RE` | `2026-06-(09\|10\|11\|12\|13\|14)` |
| `AUR_WINDOW_INSTALL_DAYS_RE` | `(0?[9]\|1[0-4])` |
| `AUR_WINDOW_INSTALL_MONTH` | `Jun` |
| `AUR_WINDOW_LABEL` | `Jun 9–14, 2026` |

## Malware IOCs (code)

Defined in `lib/common.fish`; scanned in `lib/ioc.fish` / `scripts/scan/malware-artifacts.fish`.

| Indicator | Constant / pattern | Origin |
|-----------|-------------------|--------|
| npm hooks | `AUR_MALICIOUS_NPM` | Arch reports, lenucksi `malicious_npm_packages.txt` |
| PKGBUILD hooks | `AUR_HOOK_PATTERN` | Community PKGBUILD samples |
| Non-listed heuristics | `AUR_SIMILAR_HEURISTICS_PATTERN` | Broader npm/bun/obfuscation patterns in `scan/similar-heuristics.fish` |
| ELF `deps` | `AUR_MALWARE_SHA256_DEPS` | ioctl.fail / lenucksi `iocs.txt` |
| js-digest payload | `AUR_MALWARE_SHA256_JS_DIGEST` | ioctl.fail / IFIN |
| Cryptominer staging | `AUR_MALWARE_SHA256_CRYPTO` | ioctl.fail |
| Exfil domains | `AUR_IOC_DOMAINS` | ioctl.fail C2 extraction |
| Persistence grep | `AUR_PERSISTENCE_PATTERN` | Community checks |

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1 | `scripts/check/atomic-arch-pkgs.fish` | `aur_load_atomic_arch_list`, `aur_classify_atomic_arch_installed_pkg` |
| 2 | `scripts/scan/aur-window.fish` | `AUR_WINDOW_*` |
| 3 | `scripts/scan/atomic-arch-timeline.fish` | `aur_collect_window_alpm_events*` |
| 4 | `scripts/scan/malware-artifacts.fish` | `lib/ioc.fish` |
| 4b | `scripts/scan/similar-heuristics.fish` | `aur_foreign_installed_not_on_list`, `aur_pkg_similar_heuristics_files` |
| — | `scripts/check/list-freshness.fish` | bundled vs online list delta + installed staleness check |
| — | `scripts/recovery/remove-packages.fish` | default `--list atomic-arch` |

Config: `AUR_ATOMIC_ARCH_LIST_FILE` (default: `data/lists/atomic-arch-pkgs.txt`).

## Integrity

Online fetch logs per-source SHA256 (`list_source_sha256`: `arch=…`, `cscs=…`). Merged cache SHA256 in JSON as `list_sha256`.

## License & attribution

See [third-party-notices.md](third-party-notices.md).
