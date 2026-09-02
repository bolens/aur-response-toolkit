# Agent guidance

Read `.specify/memory/constitution.md` and `CONTRIBUTING.md`.

- Treat package sources, archives, metadata, and logs as hostile; never execute
  suspect content during analysis.
- Keep scans read-only. Quarantine, removal, key changes, and recovery actions
  require explicit scoped authorization.
- Preserve report/state/exit-code contracts and run the documented Rust and
  contract checks for touched surfaces.

## Spec-driven changes

Use Spec Kit for new capabilities, architecture, security-sensitive behavior,
migrations, and coordinated multi-file changes. Keep narrow fixes, dependency
updates, prose edits, and release housekeeping in the normal repository
workflow unless their risk warrants a written specification. Keep completed
feature directories under `specs/` as decision history; do not backfill them for
finished work.
