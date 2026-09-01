# aur-response-toolkit

[User guide](https://bolens.github.io/aur-response-toolkit/) ·
[Report a problem](https://github.com/bolens/aur-response-toolkit/issues/new/choose) ·
[Security policy](SECURITY.md)

Native Rust toolkit to detect, triage, and recover from Arch User Repository
supply-chain incidents. It covers Atomic Arch, Chaos RAT, Mini Shai-Hulud, the
OpenConnect SSO validator compromise, the browsh-bin/linux-utils compromise,
the August 2026 xsnow worm, and the 2018 xeactor campaign.

The former Fish implementation and executable aliases have been removed.

## Build and install

```console
cargo build --release --locked
sudo install -Dm755 target/release/aur-response /usr/local/bin/aur-response
```

Arch packaging is available under `packaging/arch/`.
Release tags publish a native Linux x86_64 bundle and checksums. Before
publishing the AUR package, replace its temporary `SKIP` source checksum with
the tagged source checksum asset and regenerate `.SRCINFO`.

Configuration is optional:

```console
mkdir -p ~/.config/aur-response
cp config.toml.example ~/.config/aur-response/config.toml
```

An existing legacy configuration can be converted once with:

```console
aur-response config migrate /path/to/config.fish ~/.config/aur-response/config.toml
```

## Full scans

```console
aur-response
aur-response --local
aur-response --chaos-rat --shai-hulud --openconnect-sso --browsh-linux-utils --xsnow-worm --xeactor
aur-response --audit --report --json
aur-response --local --quiet --report --json --fail-on compromise --quick
aur-response --recover --report
```

`--local` uses bundled threat lists. Online scans fetch and atomically cache
source-specific parsed lists.

## Native subcommands

```console
aur-response scan packages atomic-arch --local
aur-response scan packages chaos-rat --local
aur-response scan packages shai-hulud --local
aur-response scan packages openconnect-sso --local
aur-response scan packages browsh-linux-utils --local
aur-response scan packages xsnow-worm --local
aur-response scan packages xeactor --local

aur-response scan timeline atomic-arch --local
aur-response scan timeline chaos-rat --local
aur-response scan timeline shai-hulud --local
aur-response scan timeline openconnect-sso --local
aur-response scan timeline browsh-linux-utils --local
aur-response scan timeline xsnow-worm --local
aur-response scan timeline xeactor --local

aur-response scan aur-window --local
aur-response scan malware-artifacts --quick
aur-response scan similar-heuristics --local --quick
aur-response scan hardening
aur-response check list-freshness
aur-response audit

aur-response recovery remove-packages --local --dry-run
aur-response recovery remove-packages --local --verify
aur-response recovery rotate-hints
aur-response recovery apply-hardening
aur-response recovery apply-hardening --apply
aur-response recovery scrub-history --all-shells --dry-run
```

Campaign names are `atomic-arch`, `chaos-rat`, `shai-hulud`,
`openconnect-sso`, `browsh-linux-utils`, `xsnow-worm`, and `xeactor`.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | clean |
| 1 | compromise indicators |
| 2 | warnings |
| 3 | insufficient data |
| 4 | invalid arguments |

`--fail-on` accepts `all`, `compromise`, `chaos-rat`, `shai-hulud`,
`openconnect-sso`, `browsh-linux-utils`, `xsnow-worm`, `xeactor`, or `none`.

## Reports and state

Reports, JSON summaries, findings, and scan state are written beneath
`reports/` for a writable clone or `~/.local/share/aur-response/reports/` for
system installs. Override this with `AUR_REPORTS_DIR` or `reports_dir` in TOML.
JSON summaries include each campaign's source, retrieval date, incident window,
scan window, and actual and expected list hashes. Coverage counters identify
unreadable roots, oversized skipped files, and unavailable runtime adapters. A
scan with incomplete coverage exits 3 even when it finds no indicators. The
engine checks bundled IOC and campaign-list data against `data/integrity.toml`.
Online results retain that trusted baseline.

## Development

```console
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

Tests cover configuration and migration, all native subcommand routing, exit
policy, report schemas, compressed ALPM logs, campaign package/timeline/window
matching, list parsing and cache deltas, IOC scans, audit/hardening behavior,
and guarded recovery operations.

The Pages site contains the
[non-technical user guide](https://bolens.github.io/aur-response-toolkit/).
Threat-source attribution, implementation notes, and incident records remain in
[`data/docs/`](data/docs/).
