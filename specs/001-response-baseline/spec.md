# Feature specification: Evidence-led incident scanning and explicit recovery

**Created**: 2026-09-05
**Status**: Retrospective baseline
**Inspected revision**: `fc52dfc190126f68c5c4f793526cd131e08c15f9`
**Input**: The owner requested a fleet-wide Spec Kit retrofit and implementation audit.

The native Rust CLI scans supported campaign evidence and offers distinct audit, reporting, and explicitly selected recovery workflows.

This specification records existing contracts after implementation. It does not
claim that the original work followed Spec Kit. New behavior requires a separate
change contract. Existing feature specifications remain authoritative within their
own scope.

## User scenarios and testing

### User story 1: Use the documented entry points (P1)

An operator selects a supported command or source workflow.

**Acceptance**: Inputs, output/status, and ownership remain consistent with the source contracts below.

### User story 2: Handle invalid input and partial failure (P2)

A configuration, dependency, subprocess, or persistence operation fails.

**Acceptance**: The named regression fixtures preserve failure reporting and recovery without claiming an unverified successful operation.

### User story 3: Maintain the contract (P3)

A maintainer changes the implementation or adds a supported capability.

**Acceptance**: The source registry, public documentation, tests, and delivery checks change together; operational actions remain separately scoped.

## Requirements

- **FR-001**: CLI commands and exit codes MUST distinguish clean, compromise, warnings, insufficient evidence, and invalid invocation.
- **FR-002**: Campaign data MUST pass declared registry/list integrity checks and retain source-specific parsing and bounded inspection.
- **FR-003**: Suspect PKGBUILDs and evidence MUST be inspected as hostile text rather than executed by analysis.
- **FR-004**: Package removal MUST preview scoped targets and require confirmation or explicit force outside dry-run; hardening MUST require --apply.
- **FR-005**: Explicit history scrubbing MUST offer dry-run, preserve a backup before replacement, and report read/write failures.
- **FR-006**: Configuration migration, report schemas, and optional campaign policy MUST stay compatible with their documented native contracts.

## Success criteria

- **SC-001**: Every requirement has a named source owner and acceptance check in `coverage.md`.
- **SC-002**: The listed native checks pass for the reviewed candidate, with unavailable environments and operational checks recorded separately.
- **SC-003**: Retrofitting preserves existing interfaces and completed specifications. Any confirmed implementation gap is corrected under an explicit requirement before it is marked complete.

## Edge cases and operational limits

This baseline does not assert that the workstation is free of compromise or establish new campaign facts. Fixtures prove implemented detection/recovery boundaries, not complete threat detection. No suspect package is installed, no live history is scrubbed, and no release or AUR publication is requested by this documentation change.

## Corrective requirements from the exhaustive retrofit pass

The following requirements were identified while inspecting revision
`fa7ad7c998d8196bc0cea495fea8c3a85c631081`. This pass remains in progress.

- **FR-007**: `recovery remove-packages --verify` with explicit package names MUST report only requested packages that remain in the installed-package inventory. A requested package already absent MUST NOT cause a failed verification. Verification MUST NOT invoke removal.

- **FR-008**: Applied npm hardening MUST keep an existing final unterminated line separate from the new `ignore-scripts=true` setting. Repeating apply MUST leave a single effective setting, and dry-run MUST preserve the file bytes.

- **FR-009**: Bounded evidence reads and hashes on Linux MUST reject non-regular files without waiting for a FIFO writer. Inspection MUST keep the existing no-follow and byte-limit protections.

- **FR-010**: JSON `coverage_complete` MUST be false when the scan records insufficient evidence, even when no traversal or byte-limit counter was incremented. The field MUST describe evidence coverage independently of `--fail-on` exit suppression.

- **FR-011**: Ignoring a known maintainer-comment false positive MUST NOT suppress independent suspicious instructions elsewhere in the same package script. Package text remains data and MUST NOT be executed to establish the result.

- **FR-012**: Cron evidence that cannot be decoded or read MUST contribute to incomplete coverage, using the same counters as other persistence evidence. Non-file traversal entries MUST NOT be opened as text.

- **FR-013**: Failure to create the report directory or publish required report/state/summary outputs MUST produce an explicit diagnostic and insufficient-data exit status. `--json` MUST NOT silently return success without its summary.

- **FR-014**: Both `--prune-days N` and `--prune-days=N` MUST reject values whose conversion to seconds would overflow, before engine construction or report mutation. Zero continues to disable pruning.

- **FR-015**: Atomic replacement MUST preserve an existing destination’s file permissions. Scrubbing a private shell history MUST NOT make it readable by additional users. New Unix atomic-output files MUST start with owner-only read/write permissions.

- **FR-016**: `check list-freshness` MUST compare a validated local list with freshly fetched package names without replacing the local list or its backup. It MUST report added/removed names and installed packages found only in the fresh set as `STALE-MISS` compromise indicators. Missing or empty fresh evidence and unavailable installed inventory MUST produce incomplete coverage. `--local` MUST prevent fetching and explicitly report that online freshness cannot be established. Existing `--fail-on` policy continues to control evidence exit status.
