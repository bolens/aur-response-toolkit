# AUR Response Toolkit Constitution

[Documentation](../../docs/README.md)

## Core Principles

### I. Evidence Before Remediation
Supply-chain findings MUST be traceable to collected evidence, rule versions, and explicit confidence. Detection, triage, and recovery actions MUST remain distinguishable.

### II. Safe-by-Default Incident Response
Scanning and reporting are read-only by default. Quarantine, package removal, key changes, or other recovery actions require explicit operator intent, scoped targets, and recoverable state where practical.

### III. Untrusted Package Data
PKGBUILDs, sources, archives, metadata, logs, and repository content MUST be treated as hostile. Analysis MUST avoid executing suspect content and MUST preserve secret and path redaction.

### IV. Stable Native Contracts
CLI, configuration, report, state, and exit-code contracts MUST be versioned and tested. New campaigns integrate through the established registries rather than parallel implementations.

### V. Reproducible Verification
Rules and remediations MUST have deterministic fixtures and regression tests. Required Rust, contract, and documentation checks MUST pass before release; infrastructure failures are reported separately from product failures.

## Governance

Security claims require evidence and review. Any exception that increases execution or remediation risk must be explicit, documented, and versioned.

**Version**: 1.0.0 | **Ratified**: 2026-08-15 | **Last Amended**: 2026-08-15

### CI publisher authority

The [Woodpecker delivery contract](../../docs/woodpecker-publishing.md) defines a
phased publisher migration from the canonical GitHub source. Reconciled Gitea
copies retain adoption provenance, visibility and protected squash governance;
they MUST NOT receive publisher credentials or create duplicate publications.
Explicit host cutover follows native validation and preserves required platform,
signing, provenance and domain safety contracts. Publication is not a test.
