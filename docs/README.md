# Documentation

AUR incident evidence, native CLI contracts, and recovery guidance.

## Start here

| Need | Owning document |
| --- | --- |
| Use the project | [README.md](../README.md) |
| Change the repository | [AGENTS.md](../AGENTS.md) |
| Deliver or recover | [RELEASING.md](../RELEASING.md) |
| Plan substantial changes | [.specify/memory/project-guide.md](../.specify/memory/project-guide.md) |
| Non-negotiable constraints | [.specify/memory/constitution.md](../.specify/memory/constitution.md) |

## Architecture

The Rust [engine](../src/engine.rs) coordinates collection and classification.
[Models](../src/model.rs) distinguish findings, confidence, and insufficient evidence, while
[reporting](../src/report.rs) emits the persisted contract. Detection must not execute suspect
package content or silently become remediation. [SECURITY.md](../SECURITY.md) owns the trust
boundary.

## Deployment and recovery

[Build and installation](../README.md#build-and-install) covers local use.
[RELEASING.md](../RELEASING.md) owns signed releases, packaging, and rollback. Restoring an older
executable does not reverse a quarantine, removal, or key change. Such actions require their own
scoped recovery record.

## Database and state

[Reports and state](../README.md#reports-and-state) owns artifact locations. [Report
writers](../src/report.rs) atomically persist summaries, findings, and scan state. The engine reads
prior compromise state and caches threat lists, so deleting state can discard incident context.
Preserve evidence before cleanup. There is no database server.

## Documentation maintenance

Keep decisions, invariants, failure modes, and recovery requirements in the owning document. Link to
commands, defaults, schemas, and generated catalogs instead of copying them. Change the owner and
affected references together. Update this index when adding or moving a guide, and verify relative
links and heading anchors. Historical specs and audits describe their recorded revision, not current
runtime proof. A topic without an implementation stays explicitly unimplemented.

## Topic guides

- [Contributing](../CONTRIBUTING.md)
- [Security policy](../SECURITY.md)
- [Development environments](development-environments.md)
