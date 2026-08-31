# Mini Shai-Hulud AUR list sources

This opt-in campaign covers the `crypto-javascript` npm hook in adopted AUR
packages from May 16 through May 28, 2026. This AUR wave is separate from the
broader Mini Shai-Hulud npm and PyPI worm attributed to TeamPCP. Their package
lists and incident windows differ. See the [source index](sources.md).

## Package list sources

| Tier | Source | Config |
|------|--------|--------|
| Bundled (default) | `data/lists/shai-hulud-pkgs.txt` | `AUR_SHAI_HULUD_LIST_FILE` |
| Optional remote | (user URL) | `AUR_SHAI_HULUD_URL` |

For an offline scan, use `--local --shai-hulud`. The toolkit does not merge
multiple sources for this campaign. Add names to the bundled list after
aur-general publishes them.

### Staff-confirmed packages (aur-general)

| Package | Malicious account | Date | Notes |
|---------|-------------------|------|-------|
| `gnome-vfs` | pierrethomas | 2026-05-16/17 | `npm install crypto-javascript` in install script |
| `expressvpn` | (burner) | 2026-05-16/17 | same variant |
| `atomicwallet-bin` | (burner) | 2026-05-16/17 | wallet-themed lure |
| `exodus-bin` | damienlebond | 2026-05-16/17 | wallet-themed lure |
| `plex-media-player` | new adopter | 2026-05-28 | hook ran from `/tmp` |
| `plex-media-player-v2` | new account | 2026-05-28 | duplicate with same hook |
| `plex-media-player-mod` | new account | 2026-05-28 | duplicate with same hook |
| `plex-media-player-custom` | new account | 2026-05-28 | duplicate with same hook |

Hyacinthe Cartiaux (AUR staff) confirmed these four on **2026-05-19** in response to Soufiane Fariss’s report of coordinated burner-account adoptions with `@onionmail.org` addresses.

## References

### Official and community response for the AUR

| Source | URL | Notes |
|--------|-----|-------|
| aur-general: staff reply (Hyacinthe Cartiaux) | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/MLIJANLZQNLFKK5Q2QVNJPWP2DM6KK6M/ | Confirms four `crypto-javascript` packages; cites May 16–17 window |
| aur-general: Plex package report | https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/2026/5/ | Reports four Plex variants with the same hook on May 28 |
| Arch Linux Forums: malicious AUR updates | https://bbs.archlinux.org/viewtopic.php?id=313892 | Community reports; distinguishes AUR from official repos |

The staff reply quotes the initial reporter, Soufiane Fariss. The report
describes coordinated adoption by single-package burner accounts with identical
payloads in their first commits on May 16 and 17, 2026.

### Technical analysis of the npm and PyPI worm

These sources describe the npm and PyPI Mini Shai-Hulud worm, not the AUR list
above. They are relevant because `gh-token-monitor` may also appear on developer
machines that use the AUR.

| Source | URL | Notes |
|--------|-----|-------|
| JFrog Security Research: Shai-Hulud worm | https://research.jfrog.com/post/shai-hulud-here-we-go-again/ | Worm propagation; `gh-token-monitor` IOCs; disarm before token revoke |
| Infinum: Mini Shai-Hulud response | https://infinum.com/blog/how-we-responded-to-mini-shai-hulud/ | **`rm -rf ~/`** if GitHub token revoked before removing monitor |
| Cybersecurity Reach: token wipe investigation | https://cybersecurityreach.org/investigations/ifyourevokethistokenitwillwipethecomputeroftheowner-shai-hulud-2026 | Persistence paths, recovery order |
| Security Boulevard: TanStack / 170 packages | https://securityboulevard.com/2026/05/the-tanstack-npm-supply-chain-attack-that-hit-170-packages-and-punishes-you-for-revoking-your-token/ | TeamPCP campaign name; Linux systemd paths |
| Panther: supply chain attack overview | https://panther.com/blog/shai-hulud-npm-supply-chain-attack | preinstall/Bun wave context |
| Tenable: CVE-2026-45321 FAQ | https://www.tenable.com/blog/frequently-asked-questions-cve-2026-45321-shai-hulud-2-0-supply-chain-compromise | CVE FAQ (npm ecosystem) |

### AUR payload (this list)

| Source | URL | Notes |
|--------|-----|-------|
| npm: `crypto-javascript` (malicious) | https://www.npmjs.com/package/crypto-javascript | Package name in PKGBUILD hooks (verify takedown status) |
| Socket.dev: package intel | https://socket.dev/npm/package/crypto-javascript | Supply-chain analysis portal |

### Package lists and detection tools

| Source | URL | Notes |
|--------|-----|-------|
| lenucksi/aur-malware-check | https://github.com/lenucksi/aur-malware-check | Atomic Arch focus; useful for distinguishing June 2026 wave |

## Attack window

**May 16–28, 2026**: bounded from the first staff-confirmed packages through
the later Plex variants. Installs outside this window are LOW risk unless
`--all-time`.

| Constant | Default |
|----------|---------|
| `AUR_SHAI_HULUD_YEAR` | `2026` |
| `AUR_SHAI_HULUD_WINDOW_LOG_RE` | `2026-05-(1[6-9]\|2[0-8])` |
| `AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE` | `(1[6-9]\|2[0-8])` |
| `AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH` | `May` |
| `AUR_SHAI_HULUD_WINDOW_LABEL` | `May 16–28, 2026` |

## Malware IOCs (code)

Implemented in `src/ioc.rs` and  npm cache walks in `aur-response scan malware-artifacts`.

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
2. Remove the persistence files listed above. If npm worm artifacts are present,
   also remove any `.claude` or `.vscode` hooks described by the
   cross-ecosystem sources.
3. Remove affected AUR packages (`aur-response recovery remove-packages --list shai-hulud`).
4. Rotate credentials. Audit CI runners and npm publish tokens.

```console
systemctl --user stop gh-token-monitor.service
systemctl --user disable gh-token-monitor.service
```

## Not the same campaign

| Campaign | Window | AUR hook | Toolkit flag |
|----------|--------|----------|--------------|
| **Mini Shai-Hulud AUR** (this doc) | May 16–28, 2026 | `npm install crypto-javascript` | `--shai-hulud` |
| **Atomic Arch** | Jun 9–14, 2026 | `atomic-lockfile`, `lockfile-js`, `js-digest` | default |
| **npm Shai-Hulud worm** | May 2026+ | npm/PyPI preinstall; hundreds of packages | IOC/persistence overlap only |

The June Atomic Arch campaign and the May `crypto-javascript` campaign are
separate incidents. Both use npm during `makepkg`.

## Toolkit code map

| Step | Script | Loader / helpers |
|------|--------|------------------|
| 1c | `aur-response scan packages shai-hulud` | `aur_load_shai_hulud_list`, `aur_classify_shai_hulud_pkg` |
| 3c | `aur-response scan timeline shai-hulud` | `aur_collect_shai_hulud_window_alpm_events*` |
| 4 | `aur-response scan malware-artifacts` | `AUR_SHAI_HULUD_MALICIOUS_NPM`, `aur_check_shai_hulud_persistence` |
| Not applicable | `aur-response recovery remove-packages` | `--list shai-hulud` |

| Piece | Location |
|-------|----------|
| Enable | `--shai-hulud`, `AUR_ENABLE_SHAI_HULUD` |
| JSON | `shai_hulud_*` |
| Exit policy | `--fail-on shai-hulud` |

## Integrity

The toolkit uses only the bundled list by default. An optional
`AUR_SHAI_HULUD_URL` fetch records its SHA256 through
`aur_fetch_source_with_sha`. The toolkit does not merge multiple source tiers.

## Maintenance

- Add packages to `data/lists/shai-hulud-pkgs.txt` when aur-general staff or trusted reporters confirm additional **crypto-javascript** AUR names from the May 2026 wave.
- Do **not** fold Atomic Arch package names into this list.

## License and attribution

See [third-party-notices.md](third-party-notices.md).
