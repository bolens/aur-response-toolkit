# Requirement coverage

| Requirement | Source and acceptance evidence |
| --- | --- |
| FR-001 | `src/cli.rs`, exported exit constants, engine/report policy, and CLI integration tests. |
| FR-002 | `src/integrity.rs`, `src/inspection.rs`, lists/IOC registries, tamper/oversize and parsing tests. |
| FR-003 | Inspection/IOC adapters, package fixtures, and native security/inspection tests. |
| FR-004 | `src/engine.rs:remove_packages` and ApplyHardening routing; native recovery/dry-run fixtures. |
| FR-005 | `src/engine.rs:scrub_history`, atomic config writer, history fixtures and recovery tests. Invoking this recovery command without --dry-run is a write operation. |
| FR-006 | `src/config.rs`, `src/model.rs`, `src/report.rs`, legacy migration and reporting/exit-policy tests. |

## Verification receipt

Native formatting, locked all-target Clippy with warnings denied, 65 Rust tests, and the locked release build passed. Site metadata rejection fixtures, accessibility, and workflow syntax/security passed. Separate self-review checked bounded no-follow inspection, exit/report policy, removal confirmation, explicit hardening apply, and backup-before-replacement history scrubbing. Tests used fixture package, log, history, and campaign data. No workstation scan, recovery, installation, or publication was performed.
