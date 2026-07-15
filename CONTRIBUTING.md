# Contributing

Thanks for helping improve incident response for AUR supply-chain threats.

## Before you start

1. Read [`data/docs/sources.md`](data/docs/sources.md) for how campaigns, lists, and docs are organized.
2. Install local Git hooks (once per clone):

```fish
fish scripts/install-git-hooks.fish
```

Hooks live in [`.githooks/`](.githooks/) (`core.hooksPath`). Path filters mirror CI ([`scripts/hooks/classify-paths.fish`](scripts/hooks/classify-paths.fish) ↔ `.github/workflows/ci.yml`):

| Staged changes | pre-commit runs |
|----------------|-----------------|
| Docs / non-code only | nothing (CI gate jobs still green) |
| Packaging / workflows only | skip local lint/tests (CI still runs) |
| Fish / `lib` / `scripts` / `tests` / lists | `fish_indent` + `lint.fish` + `tests/run-all.fish` |

Env: `AUR_HOOK_FULL=1` (always lint+tests), `AUR_HOOK_LINT_ONLY=1` (no tests), `AUR_SKIP_HOOKS=1` (skip hooks).

3. Run the test suite and linter locally:

```fish
fish tests/run-all.fish
fish lint.fish
```

Parallel suites locally (optional):

```fish
set -x AUR_TEST_JOBS 8
fish tests/run-all.fish
```

Install **fishcheck** if lint fails:

```fish
git clone https://github.com/mattmc3/fishcheck ~/.local/bin/fishcheck
fish_add_path -g ~/.local/bin/fishcheck
```

## Types of contributions

| Contribution | Where to start |
|--------------|----------------|
| New campaign or IOC list | Issue with sources → `data/lists/`, `data/docs/{slug}.md`, `scripts/check/`, `scripts/scan/` |
| False positive fix | Issue → adjust heuristics in `lib/` or list files with provenance |
| Bug fix | Issue → minimal fix + test in `tests/unit/` or `tests/integration/` |
| Docs only | README or `data/docs/` — keep URLs in docs, not duplicated in README |

## Code conventions

- Library entry point is [`lib/bootstrap.fish`](lib/bootstrap.fish) — it loads focused modules (`shims`, `lists`, `cli`, `windows`, `alpm`, `packages`, `campaign_runners`, …). Prefer editing the relevant module over growing a monolith.
- Fish scripts use `aur_*` helpers from `lib/` — avoid raw `grep`, `find`, `curl` at call sites.
- Scripts live under `scripts/{check,scan,audit,recovery}/` and bootstrap via `scripts/_init.fish` (sources `lib/bootstrap.fish`).
- User-facing changes: update [`CHANGELOG.md`](CHANGELOG.md) under `## Unreleased` or the next version section.
- User-facing release: bump [`VERSION`](VERSION) to match CHANGELOG.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(optional-scope): <imperative summary>
```

- **Types:** `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `style`, `revert`
- Imperative mood (“add”, “fix”, “remove”), ≤72 chars on the subject, no trailing period
- Optional scope when it helps (`ci`, `packaging`, `alpm`, campaign slug, …)
- Body only when the *why* is not obvious (breaking changes, migrations, security notes)
- Breaking changes: `feat(api)!: …` and a `BREAKING CHANGE:` footer

Examples: `fix(alpm): finish log collect before cache write`, `docs: document Conventional Commits`, `chore(deps): bump actions/checkout`.

Validate locally (also enforced on PRs by [`.github/workflows/commitlint.yml`](.github/workflows/commitlint.yml)):

```fish
fish scripts/check-conventional-commit.fish --message 'feat: add list freshness tip'
git log origin/main..HEAD --format=%s | fish scripts/check-conventional-commit.fish
```

Dependabot PRs use `chore(deps):` via [`.github/dependabot.yml`](.github/dependabot.yml).

## Adding a new campaign (outline)

1. Bundled list: `data/lists/{slug}-pkgs.txt`
2. Provenance doc: `data/docs/{slug}.md` (URLs, date window, license notes)
3. Index entry in `data/docs/sources.md`
4. Prefer extending `aur_run_optional_campaign_{pkg_check,timeline}` in `lib/campaign_runners.fish` (or shared helpers) instead of forking Chaos/Shai scripts
5. Thin wrappers: `scripts/check/{slug}-pkgs.fish` and `scripts/scan/{slug}-timeline.fish`
6. Opt-in flag on `run.fish` and config keys in `config.fish.example`
7. JSON summary fields in `lib/reports.fish`
8. Removal support in `scripts/recovery/remove-packages.fish --list {slug}`
9. Tests: fixtures in `tests/fixtures/`, suites under `tests/unit/` and `tests/integration/`
10. README: short comparison table (keep detailed IOC refs in `data/docs/`)
11. Staleness: call `aur_warn_local_list_stale $list_file` with **this** campaign’s path
12. Exit policy: list load/empty → exit `3`; optional-campaign hits → exit `2`; Atomic Arch hits → exit `1`

## Tests

- `tests/run-all.fish` discovers `test-*.fish` under `tests/unit/` and `tests/integration/`.
- Parallelism: `AUR_TEST_JOBS` (default `nproc` / 4). CI sets `AUR_TEST_JOBS=4`.
- Single suite: `fish tests/unit/lib/test-alpm-cache.fish` (any `test-*.fish` path).
- Use fixtures in `tests/fixtures/` — never point tests at a live system pacman db.
- Integration tests should set isolated temp dirs via `tests/support/test-utils.fish`.
- Mock package state with `AUR_TEST_PKG_INFO`, `AUR_TEST_INSTALLED_LIST`, or `AUR_TEST_FOREIGN_LIST`; do not call bare `pacman` from new helpers.
- Full `run.fish` integration tests must isolate host IOCs: temp `HOME`, `AUR_HELPER_CACHE_ROOTS`, `AUR_TEST_SYSTEMD_SYSTEM_DIR`, and `AUR_DEPS_SEARCH_PATHS`.
- CI runs lint once (Ubuntu), then Ubuntu + Arch test jobs in parallel; gate jobs `ubuntu` / `arch` satisfy branch protection.
- fishcheck in CI is installed only for the lint job (`tools/fishcheck`; see `.github/workflows/ci.yml`).
- Code-path filter (via `dorny/paths-filter`): Fish/lists/packaging/completions/CI workflow; docs-only PRs skip tests but still get green `ubuntu`/`arch` gates. Weekly schedule and `workflow_dispatch` always run the full suite.
- Concurrency: new pushes/PR syncs cancel in-progress runs for the same branch/PR; scheduled weekly runs are never cancelled by a push.

## Pull requests

Use the PR template checklist. Title the PR (and commits) with Conventional Commits. CI must pass (lint + Ubuntu/Arch tests) unless the change is docs-only and path filters skip CI. One logical change per PR when possible.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability disclosure vs public IOC reports.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
