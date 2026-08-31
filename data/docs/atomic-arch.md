# Atomic Arch list and IOC sources

This campaign covers `atomic-lockfile`, `lockfile-js`, and `js-digest` npm and
bun hooks in orphaned AUR packages from June 2026.

## Package list sources

`src/config.rs` and `src/engine.rs` merge the online sources. The toolkit caches
the result at `data/lists/atomic-arch-pkgs.txt`.

| Tier | URL | Config override |
|------|-----|-----------------|
| Arch HedgeDoc (staff/community) | https://md.archlinux.org/s/SxbqukK6IA | `AUR_LIST_URL_ARCH` |
| commonsourcecs detection script | https://cscs.pastes.sh/raw/aurvulntest20260611.sh | `AUR_LIST_URL_CSCS` |
| Optional third source | (user URL) | `AUR_LIST_URL_EXTRA` |

For an offline scan, `--local` uses `data/lists/atomic-arch-pkgs.txt`.

## References

### Official and community response

| Source | URL |
|--------|-----|
| Arch Linux: Active AUR malicious packages incident | https://archlinux.org/news/active-aur-malicious-packages-incident/ |
| aur-general: master thread | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/FGXPCB3ZVCJIV7FX323SBAX2JHYB7ZS4/ |
| aur-general: HedgeDoc package list | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/FCH7TT6IOVT7D477JKSVJALBKADAARSW/ |
| aur-general: first confirmed report (ALVR) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/2LGBF2AZBPVCCY4VTN6DOVUNNBURFJ2J/ |
| aur-general: first gnome-randr-rust report | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/L2JXQNYBGWOQQQXDEPEAICBHKFEFANUC/ |
| aur-general: js-digest / bun wave | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/LB6TBHDXLQRPR4UVIQULCI6MZ77XYLL2/ |

### Technical analysis

| Source | URL |
|--------|-----|
| ioctl.fail: preliminary analysis | https://ioctl.fail/preliminary-analysis-of-aur-malware/ |
| Sonatype: Atomic Arch npm campaign | https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency |
| SafeDep: Atomic Arch campaign intel | https://safedep.io/ti/campaigns/atomic-arch |
| Socket.dev: atomic-lockfile | https://socket.dev/npm/package/atomic-lockfile |
| Socket.dev: js-digest | https://socket.dev/npm/package/js-digest |

### Package lists and detection tools

| Source | URL |
|--------|-----|
| Arch HedgeDoc: merged list | https://md.archlinux.org/s/SxbqukK6IA |
| cscs: detection script / list | https://cscs.pastes.sh/raw/aurvulntest20260611.sh |
| lenucksi/aur-malware-check | https://github.com/lenucksi/aur-malware-check |

Community script lineage (Kidev, BrianCArnold, commonsourcecs, Kacper-Kondracki, quantenProjects): see upstream [README § Sources](https://github.com/lenucksi/aur-malware-check/blob/master/README.md#sources).

### Coverage

| Source | URL |
|--------|-----|
| IFIN: community triage thread | https://discourse.ifin.network/t/400-aur-packages-compromised-with-infostealer-and-rootkit/577 |
| BleepingComputer: 400+ packages | https://www.bleepingcomputer.com/news/security/over-400-arch-linux-packages-compromised-to-push-rootkit-infostealer/ |
| Phoronix: 1,500+ packages | https://www.phoronix.com/news/Arch-Linux-AUR-More-Than-1500 |

## Attack window

The incident window is June 9 through June 14, 2026. The toolkit uses package
install dates and `pacman.log` entries to assign high or low risk.

| Constant | Default |
|----------|---------|
| `AUR_WINDOW_LOG_RE` | `2026-06-(09\|10\|11\|12\|13\|14)` |
| `AUR_WINDOW_INSTALL_DAYS_RE` | `(0?[9]\|1[0-4])` |
| `AUR_WINDOW_INSTALL_MONTH` | `Jun` |
| `AUR_WINDOW_LABEL` | `Jun 9–14, 2026` |

## Malware IOCs (code)

`src/ioc.rs` implements these checks for `aur-response scan malware-artifacts`.

| Indicator | Constant / pattern | Origin |
|-----------|-------------------|--------|
| npm hooks | `AUR_MALICIOUS_NPM` | Arch reports, lenucksi `malicious_npm_packages.txt` |
| PKGBUILD hooks | `AUR_HOOK_PATTERN` | Community PKGBUILD samples |
| Non-listed heuristics | `AUR_SIMILAR_HEURISTICS_PATTERN` | Broader npm/bun/obfuscation patterns in `aur-response scan similar-heuristics` |
| ELF `deps` | `AUR_MALWARE_SHA256_DEPS` | ioctl.fail / lenucksi `iocs.txt` |
| js-digest payload | `AUR_MALWARE_SHA256_JS_DIGEST` | ioctl.fail / IFIN |
| Cryptominer staging | `AUR_MALWARE_SHA256_CRYPTO` | ioctl.fail |
| Exfil domains | `AUR_IOC_DOMAINS` | ioctl.fail C2 extraction |
| Persistence grep | `AUR_PERSISTENCE_PATTERN` | Community checks |

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1 | `aur-response scan packages atomic-arch` | `aur_load_atomic_arch_list`, `aur_classify_atomic_arch_installed_pkg` |
| 2 | `aur-response scan aur-window` | `AUR_WINDOW_*` |
| 3 | `aur-response scan timeline atomic-arch` | `aur_collect_window_alpm_events*` |
| 4 | `aur-response scan malware-artifacts` | `src/ioc.rs` |
| 4b | `aur-response scan similar-heuristics` | `aur_foreign_installed_not_on_list`, `aur_pkg_similar_heuristics_files` |
| Not applicable | `aur-response check list-freshness` | bundled vs online list delta + installed staleness check |
| Not applicable | `aur-response recovery remove-packages` | default `--list atomic-arch` |

Config: `AUR_ATOMIC_ARCH_LIST_FILE` (default: `data/lists/atomic-arch-pkgs.txt`).

## Integrity

Online fetches record a SHA256 for each source in `list_source_sha256`. JSON
reports store the merged cache SHA256 as `list_sha256`.

## License and attribution

See [third-party-notices.md](third-party-notices.md).
