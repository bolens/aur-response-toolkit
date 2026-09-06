# Contributing

[Documentation](docs/README.md)

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

1. Align `VERSION`, `Cargo.toml`, `Cargo.lock`, `PKGBUILD`, `.SRCINFO`, and the
   changelog release heading in the release PR. Set the release source checksum
   to `SKIP` in both packaging files. Never carry the previous tag's checksum
   into a new version.
2. Run the required checks and a local release build. For a native packaging
   smoke test, stage `package()` against `target/release/aur-response`; the
   GitHub tag archive does not exist before tagging. Verify the staged package
   includes `data/integrity.toml` and that a local scan can validate the bundled
   campaign data.
3. Merge the release PR only after all required GitHub checks pass.
4. Tag the merged `main` commit as `vX.Y.Z` and push the tag.
5. Wait for the Release workflow. It verifies CI on the tagged commit, publishes
   the native archive and checksums, then opens a PR with the tagged source hash.
6. Confirm the packaging PR passes CI and merges. If automation fails, run
   `python3 scripts/ci/update-release-packaging.py X.Y.Z SOURCE_SHA256`, then
   submit the two Arch manifest changes through a focused PR.
7. Download the tagged source archive and verify it matches the published source
   checksum. Build with `makepkg` and confirm that the package contains no
   build-directory references. Then publish through
   `packaging/arch/publish-to-aur.sh`.

### CI infrastructure failures

Before changing code, inspect failed logs and distinguish project failures from
runner setup failures. A check that fails before checkout with errors such as
`Failed to resolve action download info: Service Unavailable` is a GitHub
infrastructure failure. Retry the workflow when GitHub permits it. Some
generated analysis checks cannot be rerun. In that case, push the next valid
follow-up commit or close and reopen the PR to request a fresh check. Never
merge by dismissing a required infrastructure-failed check.

Check GitHub's official service status before repeatedly retrying zero-step
failures. During a declared Actions outage, pause retries until the service
recovers. Webhook triggers may remain throttled briefly afterward. Once Actions
is operational, rerun failed jobs and use the next valid commit or one
close/reopen cycle for non-rerunnable generated checks.

### Branch protection after CI migrations

When workflow or job names change, verify the required status-check contexts on
`main` before the release PR. GitHub matches those contexts by exact name, so a
stale requirement can block an otherwise passing PR. Replace obsolete contexts
with the current job names; do not bypass branch protection with an
administrator merge.

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
force flag. Add dry-run coverage for every destructive recovery path.

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
