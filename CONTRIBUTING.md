# Contributing

## Setup

```console
git config core.hooksPath .githooks
cargo build --locked
```

## Required checks

```console
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

CI runs the same checks on Ubuntu and executes the test suite in an Arch Linux
container.

## Release checklist

1. Keep `VERSION`, `Cargo.toml`, `PKGBUILD`, `.SRCINFO`, and the changelog
   release heading aligned.
2. Tag the release as `vX.Y.Z`; the release workflow publishes the native
   archive and source checksum.
3. Replace `SKIP` in `packaging/arch/PKGBUILD` with that source checksum.
4. Run `makepkg --printsrcinfo > .SRCINFO`, build with `makepkg`, and publish
   through `packaging/arch/publish-to-aur.sh`.

## Design

- `src/cli.rs` owns native subcommand and flag contracts.
- `src/config.rs` owns TOML configuration and one-time legacy import.
- `src/alpm.rs` owns pacman log and installed-package adapters.
- `src/lists.rs` owns source-specific threat-list parsing.
- `src/ioc.rs` owns runtime, persistence, and cache IOC adapters.
- `src/engine.rs` owns scans, audit, recovery, and exit policy.
- `src/report.rs` owns stable JSON/report output.

Keep external commands behind narrow adapters and use environment-injected
fixtures in tests. Destructive recovery behavior requires an explicit apply or
force flag and should always have dry-run coverage.

## Adding a campaign

Add the campaign metadata and window to `src/model.rs`, list/config fields to
`src/config.rs`, parsing rules to `src/lists.rs` where needed, engine routing,
JSON counters/findings, CLI tests, native integration fixtures, and source
attribution under `data/docs/`.

## Commits

Use Conventional Commits, for example:

```text
feat(scan): add campaign package classifier
fix(recovery): preserve dry-run history
test(cli): cover invalid campaign
```
