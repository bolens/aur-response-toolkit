# Release playbook

AUR Response Toolkit publishes Semantic Versioning releases from signed
`vX.Y.Z` tags. `VERSION` and `Cargo.toml` must agree. The Release workflow gates
on CI, builds the locked Rust binary, publishes its archive, and updates Arch
packaging through a squash-merged pull request.

## Prepare and validate

Create `release/vX.Y.Z` from current `origin/main`. Update versions with the
repository tooling, move `Unreleased` outcomes into a dated `CHANGELOG.md`
section, and update security or recovery guidance when behavior changed.

```sh
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
python3 scripts/check-changelog.py
```

Run repository contract checks documented in `CONTRIBUTING.md`. Tests and
release preparation must not execute untrusted PKGBUILDs or package sources.

## Review, publish, and verify

Do not push directly to `main`. Open a pull request, require all checks,
resolve conversations, and
squash-merge. Confirm CI succeeds on the merge SHA, then create and push a
signed annotated tag on that exact commit. Watch the Release workflow and its
packaging PR.

Verify the release archive and checksum, run the binary's version/help and a
fixture-backed read-only scan, confirm the packaging hash matches, and confirm
Pages displays the new release. Preserve evidence for the tag SHA, CI run,
asset digest, and packaging merge.

## Recover

Do not publish while CI or packaging validation is red. Never move a published
tag. Fix public defects with a new patch release; fix packaging through a new
reviewed PR. Treat any unsafe scanner or remediation behavior as a potential
security release and document affected versions.

Fleet policy: <https://github.com/bolens/.github/blob/main/RELEASING.md>.

## Source lint

The Source lint workflow checks maintained python, javascript, css, shell files selected by
[`.github/source-lint.json`](.github/source-lint.json) on every pull request
and push to `main`. Existing native checks remain part of the merge gate.
Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same tooling revision pinned in
[the workflow](.github/workflows/source-lint.yml). Review exclusions when adding
source files; generated and imported files retain their native validation.
Require the new check to pass on the current PR head before merging.
