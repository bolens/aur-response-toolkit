# Mini Shai-Hulud AUR list sources

Opt-in campaign: **`crypto-javascript`** npm hook in adopted wallet/VPN AUR packages (**May 16–17, 2026**). This is the **AUR-specific early wave** of the broader Mini Shai-Hulud npm/PyPI worm (TeamPCP); package lists and windows differ. See also [sources.md](sources.md).

## Package list sources

| Tier | Source | Config |
|------|--------|--------|
| Bundled (default) | `data/lists/shai-hulud-pkgs.txt` | `AUR_SHAI_HULUD_LIST_FILE` |
| Optional remote | (user URL) | `AUR_SHAI_HULUD_URL` |

Offline: `--local` + `--shai-hulud`. No multi-source merge yet — expand bundled list when aur-general publishes additional AUR names.

### Staff-confirmed packages (aur-general)

| Package | Malicious account | Date | Notes |
|---------|-------------------|------|-------|
| `gnome-vfs` | pierrethomas | 2026-05-16/17 | `npm install crypto-javascript` in install script |
| `expressvpn` | (burner) | 2026-05-16/17 | same variant |
| `atomicwallet-bin` | (burner) | 2026-05-16/17 | wallet-themed lure |
| `exodus-bin` | damienlebond | 2026-05-16/17 | wallet-themed lure |

Hyacinthe Cartiaux (AUR staff) confirmed these four on **2026-05-19** in response to Soufiane Fariss’s report of coordinated burner-account adoptions with `@onionmail.org` addresses.

## References

### Official & community response (AUR)

| Source | URL | Notes |
|--------|-----|-------|
| aur-general — staff reply (Hyacinthe Cartiaux) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/MLIJANLZQNLFKK5Q2QVNJPWP2DM6KK6M/ | Confirms four `crypto-javascript` packages; cites May 16–17 window |
| Arch Linux Forums — malicious AUR updates | https://bbs.archlinux.org/viewtopic.php?id=313892 | Community reports; distinguishes AUR from official repos |

Initial reporter (quoted in staff reply): **Soufiane Fariss** — coordinated adoption by single-package burner accounts, identical first-commit payload (May 16–17, 2026).

### Technical analysis (cross-ecosystem — npm/PyPI worm)

These sources describe the **npm/PyPI Mini Shai-Hulud worm**, not the four-package AUR list above. Cited because the same **`gh-token-monitor`** dead-man’s switch may appear on developer machines that also use AUR.

| Source | URL | Notes |
|--------|-----|-------|
| JFrog Security Research — Shai-Hulud worm | https://research.jfrog.com/post/shai-hulud-here-we-go-again/ | Worm propagation; `gh-token-monitor` IOCs; disarm before token revoke |
| Infinum — Mini Shai-Hulud response | https://infinum.com/blog/how-we-responded-to-mini-shai-hulud/ | **`rm -rf ~/`** if GitHub token revoked before removing monitor |
| Cybersecurity Reach — token wipe investigation | https://cybersecurityreach.org/investigations/ifyourevokethistokenitwillwipethecomputeroftheowner-shai-hulud-2026 | Persistence paths, recovery order |
| Security Boulevard — TanStack / 170 packages | https://securityboulevard.com/2026/05/the-tanstack-npm-supply-chain-attack-that-hit-170-packages-and-punishes-you-for-revoking-your-token/ | TeamPCP campaign name; Linux systemd paths |
| Panther — supply chain attack overview | https://panther.com/blog/shai-hulud-npm-supply-chain-attack | preinstall/Bun wave context |
| Tenable — CVE-2026-45321 FAQ | https://www.tenable.com/blog/frequently-asked-questions-cve-2026-45321-shai-hulud-2-0-supply-chain-compromise | CVE FAQ (npm ecosystem) |

### AUR payload (this list)

| Source | URL | Notes |
|--------|-----|-------|
| npm — `crypto-javascript` (malicious) | https://www.npmjs.com/package/crypto-javascript | Package name in PKGBUILD hooks (verify takedown status) |
| Socket.dev — package intel | https://socket.dev/npm/package/crypto-javascript | Supply-chain analysis portal |

### Package lists & detection tools

| Source | URL | Notes |
|--------|-----|-------|
| lenucksi/aur-malware-check | https://github.com/lenucksi/aur-malware-check | Atomic Arch focus; useful for distinguishing June 2026 wave |

## Attack window

**May 16–17, 2026** — staff-confirmed adoption/commit window. Installs outside this window are LOW risk unless `--all-time`.

| Constant | Default |
|----------|---------|
| `AUR_SHAI_HULUD_YEAR` | `2026` |
| `AUR_SHAI_HULUD_WINDOW_LOG_RE` | `2026-05-(16\|17)` |
| `AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE` | `(1[67])` |
| `AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH` | `May` |
| `AUR_SHAI_HULUD_WINDOW_LABEL` | `May 16–17, 2026` |

## Malware IOCs (code)

Defined in `lib/common.fish`; scanned in `lib/ioc.fish` / npm cache walks in `scripts/scan/malware-artifacts.fish`.

| Indicator | Constant / function | Origin |
|-----------|---------------------|--------|
| npm `crypto-javascript` | `AUR_SHAI_HULUD_MALICIOUS_NPM` | aur-general staff reply |
| PKGBUILD / `.install` hooks | npm cache scan (shared with Atomic Arch path) | Community PKGBUILD samples |
| `gh-token-monitor` persistence | `aur_check_shai_hulud_persistence` | JFrog, Infinum, Security Boulevard |

### Persistence paths checked

| Path | Platform |
|------|----------|
| `~/.config/systemd/user/gh-token-monitor.service` | Linux |
| `~/.local/bin/gh-token-monitor.sh` | Linux |
| `~/.config/gh-token-monitor` | Linux |

### Recovery order (critical)

1. **Stop and disable** `gh-token-monitor` before revoking GitHub/npm/cloud tokens.
2. Remove persistence files listed above (and any `.claude` / `.vscode` hooks if npm worm artifacts are present — see cross-ecosystem sources).
3. Remove affected AUR packages (`recovery/remove-packages.fish --list shai-hulud`).
4. Rotate credentials and audit CI runners / npm publish tokens.

```fish
systemctl --user stop gh-token-monitor.service
systemctl --user disable gh-token-monitor.service
```

## Not the same campaign

| Campaign | Window | AUR hook | Toolkit flag |
|----------|--------|----------|--------------|
| **Mini Shai-Hulud AUR** (this doc) | May 16–17, 2026 | `npm install crypto-javascript` | `--shai-hulud` |
| **Atomic Arch** | Jun 9–14, 2026 | `atomic-lockfile`, `lockfile-js`, `js-digest` | default |
| **npm Shai-Hulud worm** | May 2026+ | npm/PyPI preinstall; hundreds of packages | IOC/persistence overlap only |

Installing an AUR package from the **June Atomic Arch** list is a different incident from the **May crypto-javascript** wave even though both use npm during `makepkg`.

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1c | `scripts/check/shai-hulud-pkgs.fish` | `aur_load_shai_hulud_list`, `aur_classify_shai_hulud_pkg` |
| 3c | `scripts/scan/shai-hulud-timeline.fish` | `aur_collect_shai_hulud_window_alpm_events*` |
| 4 | `scripts/scan/malware-artifacts.fish` | `AUR_SHAI_HULUD_MALICIOUS_NPM`, `aur_check_shai_hulud_persistence` |
| — | `scripts/recovery/remove-packages.fish` | `--list shai-hulud` |

| Piece | Location |
|-------|----------|
| Enable | `--shai-hulud`, `AUR_ENABLE_SHAI_HULUD` |
| JSON | `shai_hulud_*` |
| Exit policy | `--fail-on shai-hulud` |

## Integrity

Bundled list only by default; optional `AUR_SHAI_HULUD_URL` fetch logs SHA256 via `aur_fetch_source_with_sha`. No multi-tier merge yet.

## Maintenance

- Add packages to `data/lists/shai-hulud-pkgs.txt` when aur-general staff or trusted reporters confirm additional **crypto-javascript** AUR names from the May 2026 wave.
- Do **not** fold Atomic Arch package names into this list.

## License & attribution

See [third-party-notices.md](third-party-notices.md).
