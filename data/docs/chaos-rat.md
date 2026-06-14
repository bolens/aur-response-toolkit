# Chaos RAT list sources

Opt-in campaign: cracked/patched browser, font, and game AUR packages delivering **CHAOS RAT** (**Jul 16–18, 2025**). Separate from the Atomic Arch npm campaign (June 2026). Merged by `aur_load_chaos_rat_list`. See also [sources.md](sources.md).

## Package list sources

| Tier | URL | Config override |
|------|-----|-----------------|
| Arch **aur-general** advisory (Quentin MICHAUD, 2025-07-18) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | `AUR_CHAOS_RAT_URL_ARCH` |
| lenucksi/aur-malware-check | https://raw.githubusercontent.com/lenucksi/aur-malware-check/master/chaos_rat_packages.txt | `AUR_CHAOS_RAT_URL_COMMUNITY` |
| Optional third source | (user URL) | `AUR_CHAOS_RAT_URL_EXTRA` |

Bundled cache: `data/lists/chaos-rat-pkgs.txt`. Offline: `--local` + `--chaos-rat`.

### Staff-confirmed vs extended list

| Package | Staff advisory | Community follow-on |
|---------|----------------|---------------------|
| `librewolf-fix-bin` | yes | yes |
| `firefox-patch-bin` | yes | yes |
| `zen-browser-patched-bin` | yes | yes |
| `vesktop-bin-patched` | — | yes (Lemmy / community reports) |
| `minecraft-cracked` | — | yes |
| `ttf-ms-fonts-all` | — | yes |
| `ttf-all-ms-fonts` | — | yes |

Attacker AUR account: **danikpapas**. Malicious patch source: `https://github.com/danikpapas/zenbrowser-patch.git` (also reported via Codeberg mirror `arch_lover3/browser-patch`).

## References

### Official & community response

| Source | URL | Notes |
|--------|-----|-------|
| Arch aur-general — Chaos RAT security advisory | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | Quentin MICHAUD; three primary packages |
| Lemmy — [PSA] Malware distributed on the AUR | https://sopuli.xyz/post/30611480 | Community follow-on packages; `systemd-initd` IOC |

### Technical analysis

| Source | URL | Notes |
|--------|-----|-------|
| tiagorlampert/CHAOS (upstream RAT) | https://github.com/tiagorlampert/CHAOS | Open-source Go RAT weaponized in this campaign |
| Acronis TRU — Chaos RAT evolution | https://www.acronis.com/en/tru/posts/from-open-source-to-open-threat-tracking-chaos-rats-evolution/ | Linux variant behavior, detection names |
| SC Media — open-source Chaos RAT in Linux attacks | https://www.scworld.com/news/open-source-chaos-rat-used-in-recent-attacks-targeting-linux | Cross-platform RAT context |

### Package lists & detection tools

| Source | URL | Notes |
|--------|-----|-------|
| lenucksi/aur-malware-check — `chaos_rat_packages.txt` | https://github.com/lenucksi/aur-malware-check/blob/master/chaos_rat_packages.txt | Extended merged list source |
| Arch aur-general advisory (HTML parse) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/ | Parsed on online fetch |

### Coverage

| Source | URL | Notes |
|--------|-----|-------|
| BleepingComputer — Arch pulls Chaos RAT packages | https://www.bleepingcomputer.com/news/security/arch-linux-pulls-aur-packages-that-installed-chaos-rat-malware/ | `danikpapas`, GitHub repo, VirusTotal |
| LinuxSecurity — CHAOS RAT warning | https://linuxsecurity.com/features/chaos-rat-in-aur | makepkg trust model, recovery guidance |
| CyberPress — Chaos RAT Linux/Windows | https://cyberpress.org/new-chaos-rat-affects-linux-and-windows-users/ | RAT capabilities summary |

## Attack window

**Jul 16–18, 2025** — packages uploaded Jul 16; removed ~Jul 18 18:00 UTC+2. Install date and pacman.log triage for HIGH vs LOW risk.

| Constant | Default |
|----------|---------|
| `AUR_CHAOS_RAT_YEAR` | `2025` |
| `AUR_CHAOS_RAT_WINDOW_LOG_RE` | `2025-07-(16\|17\|18)` |
| `AUR_CHAOS_RAT_WINDOW_INSTALL_DAYS_RE` | `(1[678])` |
| `AUR_CHAOS_RAT_WINDOW_INSTALL_MONTH` | `Jul` |
| `AUR_CHAOS_RAT_WINDOW_LABEL` | `Jul 16–18, 2025` |

## Malware IOCs

This toolkit checks **installed package names** and **pacman timeline**; runtime IOCs are manual follow-up.

| Indicator | Where to look | Origin |
|-----------|---------------|--------|
| Process name `systemd-initd` | `ps`, `/tmp` | BleepingComputer, Lemmy PSA, staff advisory |
| Malicious patch repo | PKGBUILD `source` → `zenbrowser-patch.git` | BleepingComputer, advisory |
| CHAOS RAT binary | VirusTotal / AV (`Trojan.Linux.ChaosRAT.A`) | Community upload, Acronis TRU |

**Not scanned in code:** no dedicated Chaos RAT persistence grep (unlike Atomic Arch `lib/ioc.fish`). After removal, hunt `systemd-initd` and consider rebuild from trusted backup if infection is suspected.

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
| 1b | `scripts/check/chaos-rat-pkgs.fish` | `aur_load_chaos_rat_list`, `aur_classify_chaos_rat_pkg` |
| 3b | `scripts/scan/chaos-rat-timeline.fish` | `aur_collect_chaos_rat_window_alpm_events*` |
| — | `scripts/recovery/remove-packages.fish` | `--list chaos-rat` |

| Piece | Location |
|-------|----------|
| Enable | `--chaos-rat`, `AUR_ENABLE_CHAOS_RAT` |
| JSON | `chaos_rat_*`, `chaos_rat_list_sha256` |
| Exit policy | `--fail-on chaos-rat` |

Config: `AUR_CHAOS_RAT_LIST_FILE`, `AUR_CHAOS_RAT_URL_ARCH`, `AUR_CHAOS_RAT_URL_COMMUNITY`, `AUR_CHAOS_RAT_URL_EXTRA`.

## Integrity

Online fetch logs per-source SHA256 (`list_source_sha256`: `chaos-arch-ml=…`, `chaos-community=…`, `chaos-merged=…`). Merged cache SHA256 in JSON as `chaos_rat_list_sha256`. List delta vs previous cache on refresh.

## License & attribution

See [third-party-notices.md](third-party-notices.md).
