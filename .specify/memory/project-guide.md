# aur-response-toolkit Spec Kit project guide

[Documentation](../../docs/README.md)

A Rust toolkit for evidence-based AUR supply-chain detection, triage, and scoped
recovery.

Read this guide with `AGENTS.md` and `.specify/memory/constitution.md` before
specifying, planning, or implementing a substantial change. It is project-owned
guidance, not an upstream-managed template.

## Source and ownership map

- `src/cli.rs`
- `src/config.rs`
- `src/engine.rs`
- `src/report.rs`
- `src/model.rs`
- `data/`
- `tests-rust/`

## Specification and plan decisions

Separate evidence collection, finding classification, reporting, and recovery. Define
campaign attribution, confidence, configuration, report/state schemas, and exit
semantics. Keep external commands behind adapters and integrate campaigns through
existing model and parser surfaces.

## Acceptance evidence

Cover a positive fixture, benign near-match, malformed package data, unavailable
evidence, stable report output, and dry-run recovery. Suspect PKGBUILDs and archives are
data to inspect, never code to execute.

## Validation and operational limits

```sh
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

Record Arch-specific integration coverage separately from host-native tests. Quarantine,
package removal, key changes, and real incident recovery require scoped operator
authorization.

## Working through Spec Kit

Use Spec Kit for new capabilities, architectural or security-sensitive changes,
migrations, and coordinated changes that need a written contract. Keep narrow fixes,
dependency updates, and prose maintenance in the normal PR workflow.

For a new feature, record observable acceptance criteria in `spec.md`, source ownership
and constitution checks in `plan.md`, and evidence-bearing work in `tasks.md` under the
feature directory created by Spec Kit. Resolve material unknowns before implementation.
Mark tasks complete only after their stated verification, and distinguish completed,
skipped, blocked, and manual checks. Retain completed feature documents as decision
history. Backfill finished work only when explicitly requested. Label those
specifications as retrospective baselines, record the inspected revision, and map
requirements to source and acceptance evidence. Separate observed behavior from
corrective requirements. Never imply the specification preceded its code or mark
unverified checks complete.

Keep `.specify/templates/`, `.specify/scripts/`, and generated Codex skills under their
integration manifests. Use this guide and the constitution for local customization.
Regenerate managed files through Spec Kit and verify that project-owned memory survives
updates. Follow `RELEASING.md` for push, merge, release or delivery, and recovery.

The retrospective specification register is [specs/README.md](../../specs/README.md).
