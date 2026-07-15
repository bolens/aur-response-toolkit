# Threat data sources

Per-campaign provenance, upstream URLs, toolkit code mapping, and license notes. **External reference links live in each campaign doc below** — the README points here to avoid duplication.

| Campaign | Window | Bundled list | References & code map |
|----------|--------|--------------|------------------------|
| **Atomic Arch** (primary) | Jun 9–14, 2026 | `lists/atomic-arch-pkgs.txt` | [atomic-arch.md](atomic-arch.md) |
| **Chaos RAT** (opt-in) | Jul 16–18, 2025 | `lists/chaos-rat-pkgs.txt` | [chaos-rat.md](chaos-rat.md) |
| **Mini Shai-Hulud** (opt-in) | May 16–17, 2026 | `lists/shai-hulud-pkgs.txt` | [shai-hulud.md](shai-hulud.md) |
| **xeactor** (opt-in) | Jun 7–Jul 10, 2018 | `lists/xeactor-pkgs.txt` | [xeactor.md](xeactor.md) |

## Shared code

| Concern | Location |
|---------|----------|
| Entry point: paths, FHS redirects, constants; sources siblings | `lib/bootstrap.fish` |
| grep/find/curl/sha256/hostname shims | `lib/shims.fish` |
| List path/enable helpers, staleness | `lib/lists.fish` |
| Flags, logging, state, exit policy | `lib/cli.fish` |
| Date-window predicates + classifiers | `lib/windows.fish` |
| Pacman log collect, ALPM cache, timeline helpers | `lib/alpm.fish` |
| Package/list loaders, preflight, file/hook utils | `lib/packages.fish` |
| Optional campaign check/timeline runners | `lib/campaign_runners.fish` |
| ELF/npm/bun cache scans, persistence IOCs | `lib/ioc.fish` |
| JSON summary / list SHA256 fields | `lib/reports.fish` |
| User overrides | `config.fish.example` → `~/.config/aur-response/config.fish` |

List loaders live in `lib/packages.fish` (`aur_load_atomic_arch_list`, `aur_load_*`, `aur_load_and_read_*`). Optional campaigns prefer `aur_run_optional_campaign_{pkg_check,timeline}` in `lib/campaign_runners.fish`.

## License summary

This toolkit is [MIT](../../LICENSE) (Copyright 2026 Michael Bolens). Third-party **facts** (package names, advisory text, file hashes) are cited from public incident reports; we do not ship upstream detection scripts verbatim.

Full attribution: **[third-party-notices.md](third-party-notices.md)**.

## Maintenance

Each campaign doc has a **Maintenance** / **Integrity** section. Summary:

- **Shai-Hulud:** expand bundled list if aur-general confirms more May 2026 `crypto-javascript` AUR names; optional `AUR_SHAI_HULUD_URL`. Cross-ecosystem npm worm refs live in [shai-hulud.md](shai-hulud.md) only.
- **xeactor:** bundled hand-maintained list; optional `AUR_XEACTOR_URL` if a community plain-text feed appears.
- **Chaos RAT:** online merge from Arch advisory + lenucksi; stay separate from `AUR_LIST_URL_EXTRA` (Atomic Arch opt-in only).
