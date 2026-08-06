# Source and implementation map

| Area | Native implementation |
|---|---|
| CLI and exit policy | `src/cli.rs`, `src/model.rs` |
| TOML configuration/import | `src/config.rs` |
| Pacman/ALPM events | `src/alpm.rs` |
| Threat-list parsing | `src/lists.rs` |
| Runtime and persistence IOCs | `src/ioc.rs` |
| Package, timeline, audit, recovery | `src/engine.rs` |
| JSON and reports | `src/report.rs` |
| User overrides | `config.toml.example` |

Online list URLs are configured through TOML or documented `AUR_*` environment
variables. The engine records merged-list hashes in JSON reports.
