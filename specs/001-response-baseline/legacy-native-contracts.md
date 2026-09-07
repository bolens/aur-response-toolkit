# Native legacy contracts

Retrospective inspection of `fa7ad7c998d8196bc0cea495fea8c3a85c631081`, extended by the corrective requirements in [spec.md](spec.md). These contracts describe implementation, not new campaign attribution or proof that a host is uncompromised. The site, packaging, service, and delivery audit remains in progress.

## Entry points and exit policy

`src/cli.rs` maps the default full scan; seven campaign-specific package scans and seven timelines; AUR-window, malware-artifact, similar-heuristic and hardening scans; list-freshness checking; credential audit; rotation hints; hardening apply; package removal/verification; history scrubbing; and Fish-to-TOML configuration migration. Campaign slugs are atomic-arch, chaos-rat, shai-hulud, openconnect-sso, browsh-linux-utils, xsnow-worm, and xeactor. Help/version exit without constructing a scan engine.

`src/model.rs` owns campaign display names, provenance references, date windows, finding prefixes, optional campaign membership, counters, and the `--fail-on` enum. Full scans reset persisted compromise state; individual commands retain the previous compromised flag. Default/all and compromise policies prioritize insufficient evidence (3), then compromise (1). Optional campaign and hardening warnings produce 2 when selected by the exit policy. `none` suppresses findings-based nonzero status. Invalid invocation uses 4. Recovery removal forwards the child process status. A clean exit under a suppressed policy does not establish clean findings or complete coverage.

## Configuration and filesystem ownership

`src/config.rs` reads `$XDG_CONFIG_HOME/aur-response/config.toml`, falling back to `$HOME/.config`. TOML defaults fill omitted fields, then supported `AUR_*` environment overrides apply. Search-path environment lists use platform path separators. Environment booleans accept literal `1`, `true`, and `yes`; other supplied values resolve false. Runtime loading does not execute or import Fish configuration.

Explicit migration parses `set -g NAME VALUE` as data, rejects unsupported unquoted executable syntax, expands home references, serializes known settings, and atomically writes the destination. Quoting, unknown settings, complete field preservation, destination replacement, and file modes need further acceptance coverage before migration parity is claimed.

`Paths::resolve` selects explicit `AUR_RESPONSE_DIR`, a working-directory ancestor containing `data/lists`, or `/usr/share/aur-response-toolkit`. Reports use configured `reports_dir`, an explicit-root report directory, or XDG data fallback. Pacman logs default to `/var/log` and the local database to `/var/lib/pacman/local`. Fixture overrides exist for logs, package lists, installed inventory, package dates, cache roots, cron/systemd roots, and runtime adapters.

## Campaign lists and integrity

`src/integrity.rs` checks manifest version, registry digest, and canonical campaign-list digests. The registry digest covers the registry version, malware hashes, and provenance strings. Explicit alternate list paths do not receive the canonical bundled-list digest check. Text inspection is limited to 1 MiB and artifact hashing to 16 MiB. Linux inspection rejects symlinks and, under FR-009, non-regular file descriptors without waiting for FIFO writers.

`src/lists.rs` parses plain package lines, stripped HTML lines, the named community-script array, and advisory separators without executing source text. Online refresh uses curl with a 20-second timeout and 1 MiB download limit per source; successful source sets are merged with a verified bundled list when available. Failure can fall back to the local list. Cache replacement retains a previous-list file and records added/removed counts. Canonical-cache and freshness behavior have open findings below.

## Installed packages and timelines

`src/alpm.rs` obtains foreign packages from `pacman -Qqm` or a fixture file. Local database descriptions provide package names and install epochs. Engine classification intersects exact names with the selected campaign list. `--all-time` marks matching installed packages high risk; otherwise configured/test dates and campaign windows determine classification. Atomic Arch high-risk matches set compromise; optional campaigns retain warning categories.

Timeline parsing reads sorted `pacman.log*` files, supports plain/gzip/xz/zstd/bzip2 input, and recognizes installed, upgraded, downgraded, and reinstalled ALPM entries. Compressed child readers report failure at EOF and kill/reap abandoned children. Timelines match exact package names and inclusive campaign dates or a configured window regex. Atomic Arch repeats count packages with multiple timeline events and retain each event. AUR-window scans intersect foreign inventory with events and distinguish known-list packages from unknown packages requiring review.

## Artifact and heuristic inspection

`src/engine.rs` traverses configured roots or home/helper defaults with bounded depth and no link following. Quick scans reduce depth and omit broad default system roots. Artifact candidates include package scripts, characteristic names, selected sizes, and campaign-related paths; findings require known hashes, text evidence, or the implemented embedded-ELF rule. Pacman install hooks are separately inspected. Unreadable and oversized evidence increments coverage counters.

Similar-heuristic scanning reads package scripts as bounded UTF-8 data. Default patterns include package hooks, downloader pipelines, privileged staged validators, and compound xsnow indicators. An explicit regex replaces the default regex and disables extra default compound rules. Invalid regex records insufficient evidence. FR-011 excludes only the recognized maintainer-comment noise line, preserving independent evidence elsewhere.

## Runtime and persistence adapters

`src/ioc.rs` inspects process output, network connection output, cron text, systemd service text, shell startup files, autostart entries, known artifact paths, and eBPF map names. It never starts an inspected executable. Missing process/network adapters increment incomplete-coverage counters. Service heuristics inspect ExecStart plus persistence conditions; cache scanning checks path names and known hashes. FR-012 makes cron read/decode failures visible and avoids opening non-file traversal entries. Path-only matches and heuristics remain indicators requiring operator review.

## Hardening and credential inventory

Hardening checks inspect npm ignore-scripts, selected Bun environment variables, helper settings, and risky helper history in conjunction with foreign-package activity. Audit inventories credential paths and potential secret references rather than printing credential file contents. Its findings cover SSH keys, Git/cloud/container configuration, history, and selected development environment filenames. Additional browser, messaging, npm, Vault, and GPG locations are listed as inventory. These operations do not rotate credentials.

Rotation hints derive suggestions from saved findings and existing home files. They print commands without executing them. Apply-hardening is a separate operation gated by `--apply`; FR-008 preserves an unterminated existing npm line and keeps repeat application idempotent for that case. Broader npm configuration semantics remain under review.

## Recovery and retained evidence

Package removal chooses explicit names or an installed campaign-list intersection, prints the proposed sudo/pacman command, and supports dry-run, noninteractive refusal, interactive confirmation, force, and verification. FR-007 verifies explicit targets against the installed inventory. No verification branch executes removal.

History scrubbing targets Fish by default and includes Bash/Zsh with `--all-shells`. It rejects oversized/undecodable inputs, previews with `--dry-run`, copies a timestamped backup, then atomically replaces the selected history with lines not matching the secret-reference regex. It reports read/write failures. Recovery wizard requires a terminal, previews removal, asks before changes, prints rotation hints, offers history scrubbing, and runs post-recovery quick checks. Test fixtures do not exercise live recovery.

## Reports and state

`src/report.rs` writes stable JSON metadata, campaign provenance/hashes, counters, findings, report location, severity, and coverage. Finding/state collections use sorted maps/sets. `latest-summary.json` and `.scan-findings.json` contain the summary; `.scan-state` stores counters/compromise; `.scan-findings.list` stores category/path rows. Requested text reports contain the accumulated log. FR-010 makes insufficient evidence invalidate coverage even when the exit policy returns zero. Individual atomic writes publish complete contents; the group of output files is not a transaction. FR-013 reports publication failures with status 3. FR-014 rejects overflowing prune-day arguments before engine construction. FR-015 preserves destination modes and creates new Unix outputs with mode 0600.

## Open findings and audit boundaries

These are observed gaps or candidates requiring further reproduction and correction; they are not accepted completion exceptions:

- `check list-freshness` currently reads a list but does not use `list_max_age_days` to evaluate age.
- Online refresh can replace a canonical bundled list with a merged list while leaving its expected integrity digest unchanged; a subsequent local check needs regression coverage.
- Missing install epochs can be labeled outside a campaign window rather than unknown.
- Some parsed migration/configuration fields have no active consumer, including makepkg/pamac search additions and the noise-pattern setting. Migration field loss and environment parity need explicit decisions in code/specs.
- Hardening apply and scan still need conflicting settings, failed reads, symlink, and incompatible flag coverage.
- Report retention beyond overflow rejection still needs boundary tests.
- Same-second history backup collisions and complete recovery ownership/metadata preservation need further tests. Replacement permission widening is corrected by FR-015.
- Cache hashing errors, malformed audit inputs, compressed-log limits, and missing log files need full incomplete-evidence coverage.
- The notification service template's exit-status claim and installed report paths need an isolated unit/packaging review.

The current native regression receipts are in [coverage.md](coverage.md). Ancillary source coverage and these open findings remain tracked by [tasks.md](tasks.md).
