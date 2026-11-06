# Release playbook

[Documentation](docs/README.md)

AUR Response Toolkit publishes Semantic Versioning releases from signed
`vX.Y.Z` tags. `VERSION` and `Cargo.toml` must agree. The Release workflow gates
on CI, builds the locked Rust binary, publishes its archive, and updates Arch
packaging through a squash-merged pull request.

## Woodpecker migration

[The delivery contract](docs/woodpecker-publishing.md) defines the phased native
publisher and host cutover flags. Until cutover, use the Actions procedure below.
After cutover, preserve the same reviewed signed-tag release procedure, follow
the native pipeline, verify published assets and packaging PRs, and retain the
platform exceptions documented there. Gitea reconciliation does not publish.
AUR SSH publication remains manual. Never enable duplicate publishers.

## Prepare and validate

Create `release/vX.Y.Z` from current `origin/main`. Update versions with the
repository tooling, move `Unreleased` outcomes into a dated `CHANGELOG.md`
section, and update security or recovery guidance when behavior changed.

```sh
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
python3 scripts/render-changelog.py --name "AUR Response Toolkit" \
  --base-url https://bolens.github.io/aur-response-toolkit/ \
  --accent "#f4bf75" --social-image og.png --favicon favicon.png \
  --output site/changelog/index.html --check
```

Run repository contract checks documented in `CONTRIBUTING.md`. Tests and
release preparation must not execute untrusted PKGBUILDs or package sources.

## Review, publish, and verify

Do not push directly to `main`. Open a pull request, require all checks,
resolve conversations, and
squash-merge. Confirm CI succeeds on the merge SHA, then create a
signed annotated tag on that exact commit and push only that tag. With
`WOODPECKER_PUBLISHING=true`, follow native Woodpecker validation, build and
publication, then the retained Release packaging merge coordinator. Watch the
packaging PR through its protected merge; a green native build alone does not
prove packaging completion. The legacy Release publisher is the fallback only
when publication is disabled. Follow the
[release transaction](docs/woodpecker-publishing.md#release-transaction).

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

Maintained Python, JavaScript, CSS and shell files selected by
[`.github/source-lint.json`](.github/source-lint.json) are checked by Woodpecker's
`source-and-workflow-policy` step. The hosted Source lint workflow remains a
required fallback until both `WOODPECKER_LINUX_CI` and `WOODPECKER_PUBLISHING`
are literal `true`; coordinated retirement then leaves the native source check
required. Follow the active required-check contract on the current PR head.
Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same tooling revision pinned in
[the workflow](.github/workflows/source-lint.yml). Review exclusions when adding
source files; generated and imported files retain their native validation.
Require every active source-lint producer to pass before merging.

Native publisher enablement and rollback coordinate the GitHub flag with the
Woodpecker `config_file` profile. Follow the [profile and drain sequence](docs/woodpecker-publishing.md#validation-only-and-publishing-profiles);
the publishing flag alone is not a complete rollback.
