# Plan: Evidence-led incident scanning and explicit recovery

The [specification](spec.md) preserves existing behavior. Use the project guide
and constitution for implementation constraints. Keep upstream-managed templates,
helpers, and integration manifests unchanged.

## Source ownership

- `src/cli.rs`
- `src/config.rs`
- `src/alpm.rs`
- `src/lists.rs`
- `src/ioc.rs`
- `src/inspection.rs`
- `src/integrity.rs`
- `src/engine.rs`
- `src/report.rs`
- `data/integrity.toml`
- `tests`

## Constitution check

Preserve the existing constitution, canonical source ownership, explicit operational authority, deterministic failure behavior, and native validation. This retrospective baseline changes project-owned documentation; it introduces no live deployment, credentials, privileged action, or product release.

## Validation

```sh
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
cargo build --release --locked
bash scripts/ci/test-build-site-release-metadata.sh
python3 scripts/ci/check-site-accessibility.py
actionlint
zizmor --offline --min-severity medium --min-confidence medium .github
```

Run checks in an isolated checkout. Commands are instructions, not evidence of
a pass. Record results in `coverage.md`, keep incomplete work in `tasks.md`, and
follow `RELEASING.md` for reviewed delivery. No live operation is required solely
to create this retrospective baseline.
