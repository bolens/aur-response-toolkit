# Source and implementation map

| Area | Native implementation |
|---|---|
| CLI and exit policy | `src/cli.rs`, `src/model.rs` |
| TOML configuration/import | `src/config.rs` |
| Pacman/ALPM events | `src/alpm.rs` |
| Threat-list parsing | `src/lists.rs` |
| Runtime and persistence IOCs | `src/ioc.rs` |
| Bounded hostile-file inspection | `src/inspection.rs` |
| Bundled corpus integrity | `src/integrity.rs`, `data/integrity.toml` |
| Package, timeline, audit, recovery | `src/engine.rs` |
| JSON and reports | `src/report.rs` |
| User overrides | `config.toml.example` |

Configure online list URLs through TOML or the documented `AUR_*` environment
variables. The engine checks bundled lists before use and retains them as the
trusted baseline for online merges. JSON reports record the actual and expected
hashes.

## Incident references

| Campaign | Incident notes |
|---|---|
| Atomic Arch | [atomic-arch.md](atomic-arch.md) |
| Chaos RAT | [chaos-rat.md](chaos-rat.md) |
| Mini Shai-Hulud | [shai-hulud.md](shai-hulud.md) |
| OpenConnect SSO validator | [openconnect-sso.md](openconnect-sso.md) |
| browsh-bin / linux-utils | [browsh-linux-utils.md](browsh-linux-utils.md) |
| xsnow worm | [xsnow-worm.md](xsnow-worm.md) |
| xeactor | [xeactor.md](xeactor.md) |
