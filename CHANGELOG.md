# Changelog

All notable changes to **aur-response-toolkit** are documented here.

## Unreleased

### Added
- **Fish completions** — `completions/aur-response.fish` (user + FHS/AUR installs); user install also wraps `aur-response`
- **GitHub repo hygiene** — `SECURITY.md`, `CONTRIBUTING.md`, issue/PR templates, `CODEOWNERS`, Dependabot for Actions
- **CI** — Arch Linux container job, lint-before-test, concurrency, weekly schedule, `workflow_dispatch`; bump `actions/checkout@v6`, `softprops/action-gh-release@v3`
- **Release automation** — GitHub Release workflow on `v*` tags (changelog excerpt from this file)
- **`reports/.gitkeep`** — preserve empty reports directory in clones
- **`aur_pkg_is_installed`** — mock-aware install check that avoids Fish "Unknown command" when `pacman` is absent
- **Preflight** — warn when `pacman` is missing (non-Arch hosts / Ubuntu CI)
- **Test hooks** — `AUR_TEST_SYSTEMD_SYSTEM_DIR` / `AUR_TEST_SKIP_LD_PRELOAD` so integration runs ignore host persistence
- **`aur_atomic_arch_list_write_path` / `AUR_ATOMIC_ARCH_LIST_WRITE_FILE`** — redirect online merges (list-freshness uses a temp file)
- **Shared campaign helpers** — `aur_classify_campaign_pkg`, `aur_collect_alpm_events[_all]`, `aur_collect_all_time_alpm_events_all`, `aur_load_and_read_{chaos_rat,shai_hulud,xeactor}_list`, `aur_load_single_url_pkg_list`
- **FHS list caches** — when `data/lists/` is read-only, online merges go to `~/.local/share/aur-response/lists/` (bundled lists still used for `--local` / freshness)
- **`aur_run_optional_campaign_{pkg_check,timeline}`** — shared runners for chaos-rat / shai-hulud / xeactor scripts
- **`AUR_ALPM_CACHE_DIR`** — `run.fish` reuses pacman-log event collects across subprocess steps
- **Unified list helpers** — `aur_list_file_path` / `aur_list_write_path` / `aur_optional_campaign_enabled`
- **Tests** — ALPM cache, FHS list paths, list-freshness CLI, staged `install.fish`, stolen-credentials exits
- **`aur_warmup_alpm_event_caches`** — `run.fish` pre-fills the shared ALPM event cache before window/timeline steps
- **`AUR_TEST_JOBS`** — parallel suite runner in `tests/run-all.fish` (default `nproc` / 4)

### Fixed
- **`aur_collect_alpm_events`** — read logs via tempfile instead of `| while` so collection finishes before cache write (Arch CI flake)
- **`run.fish --help`** — document all flags and step 4b; unknown options point at `--help`
- **`recovery/rotate-hints.fish --help`** — print usage instead of running hints
- **`check/list-freshness.fish --help`** — only advertise flags this script uses
- **README recovery steps** — renumber scrub-history to step 7; clarify clone vs FHS systemd timers

### Changed
- **fish_indent** — formatting pass across Fish scripts (fishcheck FC1001)
- **`aur_hostname`** — fall back to `uname -n` when `hostname` is absent (minimal Arch / CI containers)
- **`aur_list_staleness_days`** — floor to whole days (fixes flaky stale-list regex / equality on sub-second mtime skew)
- **`aur_warn_local_list_stale`** — accept optional list path so Chaos/Shai-Hulud/xeactor `--local` ages the correct file
- **Ubuntu CI deps** — install `zstd`, `iproute2`, `procps` for parity with the Arch job
- **`check/list-freshness.fish`** — never overwrites the bundled list; fetch/data failures exit `3` (insufficient), not compromise
- **List-load exit policy** — Atomic Arch check joins optional campaigns: missing/empty list → exit `3` (confirmed hits stay exit `1`)
- **Optional check scripts** — load via `aur_load_and_read_*` so log lines no longer inflate package counts
- **Arch CI** — refresh `archlinux-keyring` before installing packages
- **`recovery/remove-packages.fish`** — require `pacman`; non-TTY needs `--force`; missing list exits `3`
- **`test-curl-shim`** — curlie path uses offline `file://` fixture (no live `example.com`)
- **`lib/` split** — `lib/bootstrap.fish` is the entry point (paths/constants + sources siblings); helpers live in `shims` / `lists` / `cli` / `windows` / `alpm` / `packages` / `campaign_runners` (no `lib/common.fish`)
- **Timeline repeat scans** — only run when timeline hits exist (atomic-arch + optional campaigns)
- **Deps ELF search** — drop `$HOME/.npm` / `$HOME/node_modules` from default roots; apply `-maxdepth` (10 / 6 with `--quick`)
- **CI** — pin `mattmc3/fishcheck` to a commit SHA; lint once then parallel Ubuntu/Arch tests; path filters on push/PR; `AUR_TEST_JOBS=4`
- **Docs** — FHS report paths in README flag table; config.fish trust boundary in `SECURITY.md`; CONTRIBUTING + PR template use Conventional Commits; `data/docs/sources.md` maps modular `lib/`
- **`run.fish`** — `--quiet` on a non-TTY implies `--quick` (timers/CI default to narrower artifact walks)

### Removed
- **`packaging/arch/fhs-writable-state.patch`** — FHS/XDG report+list redirects are in-tree; PKGBUILD no longer patches; `publish-to-aur.sh` no longer syncs the patch
- **`lib/common.fish`** — use `lib/bootstrap.fish` as the library entry point

## 1.9.0

### Changed
- **JSON summary keys** — Atomic Arch counters/findings renamed to match other campaigns: `installed_infected` → `atomic_arch_installed`, `installed_high_risk` → `atomic_arch_high_risk`, `timeline_hits` → `atomic_arch_timeline_hits`, `timeline_repeat_updates` → `atomic_arch_timeline_repeat_updates`
- **Helper renames** — `aur_installed_infected_pkgs` → `aur_installed_atomic_arch_pkgs`, `aur_classify_installed_infected_pkg` → `aur_classify_atomic_arch_installed_pkg`
- **Test fixtures** — `tests/fixtures/pkgbuilds/PKGBUILD.{malicious,clean}` → `pkgbuild.{malicious,clean}` (lowercase fixture names; live cache paths still use `PKGBUILD`)

## 1.8.0

### Changed
- **Data layout** — package lists under `data/lists/`; provenance docs under `data/docs/`
- **Doc filenames** — index `sources.md`; per-campaign `{slug}.md`; `third-party-notices.md` (replaces `SOURCES-*.md` / `THIRD-PARTY-NOTICES.md`)
- **Test layout** — unit suites grouped under `tests/unit/{check,scan,audit,recovery,lib}/`; integration suites under `tests/integration/{cli,scan,recovery,run}/`; shared helpers in `tests/support/`; `run-all.fish` auto-discovers suites (`fd` preferred, `find` fallback)
- **Report prefix** — `credential-audit-` → `stolen-credentials-` on credential audit reports
- **`aur_data_path`** helper in `lib/common.fish`

### Removed
- Legacy install symlinks (`atomic-*` flat names)
- Legacy config directory (`~/.config/atomic-arch-response/`) and renamed config keys (`AUR_LIST_FILE`, `AUR_ENABLE_LEGACY_2018`, `AUR_LEGACY_2018_*`, `AUR_CHAOS_RAT_URL`)
- `--list infected` alias on `recovery/remove-packages.fish`

## 1.7.0

### Changed
- **Script layout** — flat `scripts/*.fish` reorganized into `scripts/{check,scan,audit,recovery}/` with category-prefixed names (e.g. `scan/atomic-arch-timeline.fish`, formerly `scan-pacman-timeline.fish`)
- **Recovery rename** — `remove-infected.fish` → `recovery/remove-packages.fish`
- **Report log prefixes** — `infected-pkg-scan-` → `atomic-arch-pkg-scan-`, `pacman-timeline-` → `atomic-arch-timeline-`
- **Test fixtures** — grouped under `tests/fixtures/{lists,logs,pkgbuilds,history,fetch,env,misc}/`
- **`install.fish`** — installs `aur-{category}-{script}.fish` symlinks
- **`aur_script_path`** helper in `lib/common.fish` for canonical script paths

## 1.6.0

### Changed
- **Repository rename** — `atomic-arch-response-toolkit` → `aur-response-toolkit` (multi-campaign scope)
- Config directory `~/.config/aur-response/`
- Portable entry point `bin/aur-run.fish` (replaces `bin/atomic-run.fish`)
- systemd units `aur-response-scan.{service,timer}` and `aur-response-notify@.service` (replace `atomic-arch-*`)

## 1.5.0

### Added
- **2018 xeactor AUR support** (opt-in, separate from Atomic Arch, Chaos RAT, and Shai-Hulud)
  - Bundled `data/lists/xeactor-pkgs.txt` (`acroread`, `balz`, `minergate`)
  - `scripts/check/xeactor-pkgs.fish` — installed check with **Jun 7–Jul 10, 2018** HIGH/LOW triage and `--all-time`
  - `scripts/scan/xeactor-timeline.fish` — pacman log timeline (step 3d, opt-in)
  - `--xeactor` flag and `AUR_ENABLE_XEACTOR=1` config opt-in for `run.fish`
  - `recovery/remove-packages.fish --list xeactor`
  - JSON summary fields `xeactor_*` and `--fail-on xeactor` exit policy
- **Source documentation** — per-campaign `data/docs/SOURCES-*.md`, index `data/docs/sources.md`, `data/docs/third-party-notices.md`; removed obsolete `docs/PLANNED.md`
- **Attack-name consistency** — `legacy-2018` → `xeactor`; `infected-pkgs.txt` → `atomic-arch-pkgs.txt`; `check-infected-pkgs.fish` → `check/atomic-arch-pkgs.fish`; JSON fields `legacy_2018_*` → `xeactor_*`

## 1.4.0

### Added
- **Mini Shai-Hulud AUR support** (opt-in, separate from Atomic Arch and Chaos RAT)
  - Bundled `data/lists/shai-hulud-pkgs.txt` (staff-confirmed: `gnome-vfs`, `expressvpn`, `atomicwallet-bin`, `exodus-bin`)
  - `scripts/check/shai-hulud-pkgs.fish` — installed check with **May 16–17, 2026** HIGH/LOW triage and `--all-time`
  - `scripts/scan/shai-hulud-timeline.fish` — pacman log timeline (step 3c, opt-in)
  - `--shai-hulud` flag and `AUR_ENABLE_SHAI_HULUD=1` config opt-in for `run.fish`
  - `recovery/remove-packages.fish --list shai-hulud`
  - JSON summary fields `shai_hulud_*` and `--fail-on shai-hulud` exit policy
  - Artifact scan: `crypto-javascript` npm cache detection and `gh-token-monitor` persistence IOCs
- `nextfile-js` added to Atomic Arch malicious npm IOC set

## 1.3.0

### Added
- **Chaos RAT package list support** (opt-in, separate from Atomic Arch)
  - Multi-source merge: official [Arch aur-general advisory](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/) + community list
  - Per-source and merged list SHA256 (`list_source_sha256`, JSON `chaos_rat_list_sha256`); see `data/docs/chaos-rat.md`
  - `scripts/check/chaos-rat-pkgs.fish` — installed-only check with **Jul 16–18, 2025** HIGH/LOW triage and `--all-time`
  - `scripts/scan/chaos-rat-timeline.fish` — pacman log timeline for Chaos RAT list (step 3b, opt-in)
  - `--chaos-rat` flag and `AUR_ENABLE_CHAOS_RAT=1` config opt-in for `run.fish`
  - `recovery/remove-packages.fish --list chaos-rat` for removal of Chaos RAT packages
  - JSON summary field `chaos_rat_installed` and `--fail-on chaos-rat` exit policy
- Compressed pacman log support (`.gz`, `.xz`, `.zst`, `.bz2`) for window and timeline scans
- `--all-time` flag — ignore Jun 9–14 window for installed-package and pacman-log timeline checks
- Campaign ELF detection for js-digest and cryptominer SHA256 IOCs (in addition to `deps` / atomic-lockfile)
- npm cache scan via `npm cache ls`, global `node_modules`, and npm cache directory
- bun cache scan via `bun pm cache ls` and `~/.bun/install/cache` (Wave 2 / js-digest)
- Behavioral tests for compressed logs, `--all-time`, cache/ELF detection, and `aur_find` GNU find shim
- Test hooks: `AUR_TEST_INSTALLED_LIST`, `AUR_TEST_PKG_INFO`, `AUR_TEST_NPM_CACHE_DIR`

### Changed
- `aur_find` prefers `fd` for simple walks; falls back to GNU `find` for `-mtime`/`-perm`/`-size` and grouped `-name` expressions
- `aur_find_deps_elf` hash-matches embedded payloads inside malicious npm/bun package dirs
- Malware artifact scan labels campaign ELF section generically (multi-hash IOC set)

## 1.2.0

### Added
- Tab-delimited findings store (`reports/.scan-findings.list`) — safe for commas in pacman log lines
- Split `lib/common.fish` into `findings.fish`, `history.fish`, `ioc.fish`, and `reports.fish`
- Tiered AUR window scan: critical unknowns exit `1`, benign unknowns exit `2`
- Extra persistence checks in malware scan: `ld.so.preload`, systemd units, shell rc, autostart
- `scripts/recovery/apply-hardening.fish` — dry-run or `--apply` for npm `ignore-scripts=true`
- `bin/atomic-run.fish` portable entry point (resolves clone path)
- `--prune-days N` report retention in `run.fish`
- `AUR_LIST_URL_EXTRA` optional third infected-package list source (merged on fetch)
- JSON summary `findings` arrays for audit categories (`audit_ssh_keys`, `audit_git_paths`, etc.)
- Post-recovery quick verification scan in `--recover` wizard (packages + artifacts)
- `aur_log_insufficient_help` hints when exit code is `3`
- Config directory `~/.config/atomic-arch-response/` with legacy `~/.config/aur-response/` fallback
- `install.fish` migrates legacy config and installs `atomic-*` script symlinks
- `systemd/atomic-arch-scan.{service,timer}` weekly user timer (replaces `aur-malware-check`)
- `systemd/atomic-arch-notify@.service` example notify-on-scan unit
- Test suites: findings tab format, report prune, apply-hardening, rotate-hints from findings (14 total)
- CI runs `fish lint.fish` after tests
- Credential audit covers Zen Browser and Floorp cookie stores
- Credential audit runs persistence IOC check via `aur_log_persistence_findings`
- Hardening scan: bun `BUN_INSTALL` / `BUN_INSTALL_BIN` env checks and shell-history IOC domain references
- Online list fetch records `list_source_sha256` findings per source URL
- `install.fish` portable wrappers pin `AUR_RESPONSE_DIR` (works if clone moves after install)

### Changed
- Installed script symlinks use `atomic-*` prefix (was `aur-*`)
- Credential audit labels `[EXPOSED]` → `[INVENTORY]` (inventory only; never prints secrets)
- Credential audit messaging: `ACTION REQUIRED` vs `INVENTORY ONLY` based on compromise state
- Credential audit exits `2` on inventory alone when no compromise (unless `--if-compromised`)
- `recovery/rotate-hints.fish` reads audit findings when available; falls back to rediscovery when standalone
- `scan/hardening.fish` correlates `--noconfirm` history with window AUR activity (not dateless bash/zsh lines)
- Summary dashboard shows toolkit version, runtime IOC count, insufficient-data count, and severity
- `lint.fish` also checks `install.fish` and `bin/atomic-run.fish`
- `.gitignore` ignores `.scan-findings.json` runtime copy
- `systemd/atomic-arch-scan.service` uses `--fail-on compromise --quick` (timers ignore hardening-only exit `2`)

### Fixed
- `aur_history_has_window_ioc` replaced with `aur_history_noconfirm_during_window`
- `AUR_DEV_ROOT` default no longer concatenates paths incorrectly
- `pgrep` runtime IOC matching tightened to avoid toolkit false positives
- `ioc.fish` sourced after hook-pattern helpers are defined
- `aur_state_get` uses exact key match (keys containing `.` no longer mis-match)
- `--recover` blocked with `--quiet` on non-TTY stdin
- Benign unknown AUR packages no longer force credential audit (only compromise exits do)
- Credential audit `aur_compromise_detected` check used exit status, not command substitution (fixed `test: Missing argument` errors)

## 1.1.0

### Added
- Structured exit codes: `0` clean, `1` compromise, `2` warnings, `3` insufficient data, `4` invalid args
- `aur_finalize_exit` with `--fail-on all|compromise|none` policy
- `VERSION` file and `--version` flag
- `--recover` interactive recovery wizard (remove → rotate → scrub)
- `--quick` faster artifact scans (narrower search paths)
- `--if-compromised` credential audit mode (inventory without failing clean runs)
- `--json` machine-readable summary (`reports/latest-summary.json`)
- Structured `findings` arrays in JSON (packages, timeline lines, artifact paths)
- `severity`, `list_sha256`, `runtime_iocs`, and `insufficient_data` in JSON summary
- Sticky `aur_mark_compromised` flag shared across scan steps
- `install.fish`, `run.sh` (bash wrapper), and `config.fish.example`
- `recovery/remove-packages.fish --verify` post-removal check
- `aur_validate_known_flags` on scripts (unknown flags exit `4`)
- GitHub Actions CI workflow running `fish tests/run-all.fish`
- Online list fetch logs SHA256 checksums per source; `--local` warns when bundled list is stale

### Fixed
- jq JSON writer: Fish reserved word `fi` renamed; `--arg` paths properly quoted
- Invalid CLI arguments exit `4` instead of `2`

## 1.0.0

- Initial release: seven-step scan orchestrator, infected-package list merge, credential audit, recovery scripts
