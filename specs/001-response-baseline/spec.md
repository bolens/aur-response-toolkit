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
