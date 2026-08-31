# Chaos RAT list sources

This opt-in campaign covers cracked or patched browser, font, and game AUR
packages that delivered CHAOS RAT from July 16 through July 18, 2025. It is
separate from the June 2026 Atomic Arch npm campaign. See the
[source index](sources.md).

## Package list sources

| Tier | URL | Config override |
|------|-----|-----------------|
| Arch **aur-general** advisory (Quentin MICHAUD, 2025-07-18) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | `AUR_CHAOS_RAT_URL_ARCH` |
| lenucksi/aur-malware-check | https://raw.githubusercontent.com/lenucksi/aur-malware-check/master/chaos_rat_packages.txt | `AUR_CHAOS_RAT_URL_COMMUNITY` |
| Optional third source | (user URL) | `AUR_CHAOS_RAT_URL_EXTRA` |

The bundled cache is `data/lists/chaos-rat-pkgs.txt`. For an offline scan, use
`--local --chaos-rat`.

### Staff-confirmed and extended lists

| Package | Staff advisory | Community follow-on |
|---------|----------------|---------------------|
| `librewolf-fix-bin` | yes | yes |
| `firefox-patch-bin` | yes | yes |
| `zen-browser-patched-bin` | yes | yes |
| `vesktop-bin-patched` | Not applicable | yes (Lemmy / community reports) |
| `minecraft-cracked` | Not applicable | yes |
| `ttf-ms-fonts-all` | Not applicable | yes |
| `ttf-all-ms-fonts` | Not applicable | yes |

The attacker used the AUR account `danikpapas`. Reports identified
`https://github.com/danikpapas/zenbrowser-patch.git` as the malicious patch
source and `arch_lover3/browser-patch` as a Codeberg mirror.

## References

### Official and community response

| Source | URL | Notes |
|--------|-----|-------|
| Arch aur-general: Chaos RAT security advisory | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | Quentin MICHAUD; three primary packages |
| Lemmy: [PSA] Malware distributed on the AUR | https://sopuli.xyz/post/30611480 | Community follow-on packages; `systemd-initd` IOC |

### Technical analysis

| Source | URL | Notes |
|--------|-----|-------|
| tiagorlampert/CHAOS (upstream RAT) | https://github.com/tiagorlampert/CHAOS | Open-source Go RAT weaponized in this campaign |
| Acronis TRU: Chaos RAT evolution | https://www.acronis.com/en/tru/posts/from-open-source-to-open-threat-tracking-chaos-rats-evolution/ | Linux variant behavior, detection names |
| SC Media: open-source Chaos RAT in Linux attacks | https://www.scworld.com/news/open-source-chaos-rat-used-in-recent-attacks-targeting-linux | Cross-platform RAT context |

### Package lists and detection tools

| Source | URL | Notes |
|--------|-----|-------|
| lenucksi/aur-malware-check: `chaos_rat_packages.txt` | https://github.com/lenucksi/aur-malware-check/blob/master/chaos_rat_packages.txt | Extended merged list source |
| Arch aur-general advisory (HTML parse) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | Parsed on online fetch |

### Coverage

| Source | URL | Notes |
|--------|-----|-------|
| BleepingComputer: Arch pulls Chaos RAT packages | https://www.bleepingcomputer.com/news/security/arch-linux-pulls-aur-packages-that-installed-chaos-rat-malware/ | `danikpapas`, GitHub repo, VirusTotal |
| LinuxSecurity: CHAOS RAT warning | https://linuxsecurity.com/features/chaos-rat-in-aur | makepkg trust model, recovery guidance |
| CyberPress: Chaos RAT Linux/Windows | https://cyberpress.org/new-chaos-rat-affects-linux-and-windows-users/ | RAT capabilities summary |

## Attack window

The packages appeared on July 16, 2025, and were removed around 18:00 UTC+2 on
July 18. The toolkit uses package install dates and `pacman.log` entries to
assign high or low risk.

| Constant | Default |
|----------|---------|
| `AUR_CHAOS_RAT_YEAR` | `2025` |
| `AUR_CHAOS_RAT_WINDOW_LOG_RE` | `2025-07-(16\|17\|18)` |
| `AUR_CHAOS_RAT_WINDOW_INSTALL_DAYS_RE` | `(1[678])` |
| `AUR_CHAOS_RAT_WINDOW_INSTALL_MONTH` | `Jul` |
| `AUR_CHAOS_RAT_WINDOW_LABEL` | `Jul 16–18, 2025` |

## Malware IOCs

The toolkit checks installed package names and the pacman timeline. Investigate
runtime IOCs manually.

| Indicator | Where to look | Origin |
|-----------|---------------|--------|
| Process name `systemd-initd` | `ps`, `/tmp` | BleepingComputer, Lemmy PSA, staff advisory |
| Malicious patch repo | PKGBUILD `source` → `zenbrowser-patch.git` | BleepingComputer, advisory |
| CHAOS RAT binary | VirusTotal / AV (`Trojan.Linux.ChaosRAT.A`) | Community upload, Acronis TRU |

The code does not scan for Chaos RAT persistence. After removal, look for
`systemd-initd`. If the evidence indicates infection, consider rebuilding from
a trusted backup.

## Not the same campaign

| Campaign | Window | Payload | This toolkit |
|----------|--------|---------|--------------|
| **Chaos RAT** (this doc) | Jul 2025 | Go RAT via malicious browser-patch git source | `--chaos-rat` |
| **Atomic Arch** | Jun 2026 | `atomic-lockfile` / `js-digest` npm hooks | default scan |
| **Mini Shai-Hulud AUR** | May 2026 | `crypto-javascript` npm hook | `--shai-hulud` |

Do not merge Chaos RAT URLs into `AUR_LIST_URL_EXTRA` (Atomic Arch third source).

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1b | `aur-response scan packages chaos-rat` | `aur_load_chaos_rat_list`, `aur_classify_chaos_rat_pkg` |
| 3b | `aur-response scan timeline chaos-rat` | `aur_collect_chaos_rat_window_alpm_events*` |
| Not applicable | `aur-response recovery remove-packages` | `--list chaos-rat` |

| Piece | Location |
|-------|----------|
| Enable | `--chaos-rat`, `AUR_ENABLE_CHAOS_RAT` |
| JSON | `chaos_rat_*`, `chaos_rat_list_sha256` |
| Exit policy | `--fail-on chaos-rat` |

Config: `AUR_CHAOS_RAT_LIST_FILE`, `AUR_CHAOS_RAT_URL_ARCH`, `AUR_CHAOS_RAT_URL_COMMUNITY`, `AUR_CHAOS_RAT_URL_EXTRA`.

## Integrity

Online fetches record a SHA256 for each source in `list_source_sha256`. JSON
reports store the merged cache SHA256 as `chaos_rat_list_sha256`. A refresh also
records the difference from the previous cache.

## License and attribution

See [third-party-notices.md](third-party-notices.md).
