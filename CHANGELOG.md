# Changelog

All notable changes to **atomic-arch-response-toolkit** are documented here.

## 1.2.0

### Added
- Tab-delimited findings store (`reports/.scan-findings.list`) — safe for commas in pacman log lines
- Split `lib/common.fish` into `findings.fish`, `history.fish`, `ioc.fish`, and `reports.fish`
- Tiered AUR window scan: critical unknowns exit `1`, benign unknowns exit `2`
- Extra persistence checks in malware scan: `ld.so.preload`, systemd units, shell rc, autostart
- `scripts/apply-hardening.fish` — dry-run or `--apply` for npm `ignore-scripts=true`
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
- `rotate-hints.fish` reads audit findings when available; falls back to rediscovery when standalone
- `scan-hardening.fish` correlates `--noconfirm` history with window AUR activity (not dateless bash/zsh lines)
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
- `remove-infected.fish --verify` post-removal check
- `aur_validate_known_flags` on scripts (unknown flags exit `4`)
- GitHub Actions CI workflow running `fish tests/run-all.fish`
- Online list fetch logs SHA256 checksums per source; `--local` warns when bundled list is stale

### Fixed
- jq JSON writer: Fish reserved word `fi` renamed; `--arg` paths properly quoted
- Invalid CLI arguments exit `4` instead of `2`

## 1.0.0

- Initial release: seven-step scan orchestrator, infected-package list merge, credential audit, recovery scripts
