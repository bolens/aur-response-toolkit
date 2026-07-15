# Contributing

Thanks for helping improve incident response for AUR supply-chain threats.

## Before you start

1. Read [`data/docs/sources.md`](data/docs/sources.md) for how campaigns, lists, and docs are organized.
2. Run the test suite and linter locally:

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
- Use fixtures in `tests/fixtures/` — never point tests at a live system pacman db.
- Integration tests should set isolated temp dirs via `tests/support/test-utils.fish`.
- CI runs lint once (Ubuntu), then Ubuntu + Arch test jobs in parallel. Mock package state with `AUR_TEST_PKG_INFO`, `AUR_TEST_INSTALLED_LIST`, or `AUR_TEST_FOREIGN_LIST`; do not call bare `pacman` from new helpers.
- Full `run.fish` integration tests must isolate host IOCs: temp `HOME`, `AUR_HELPER_CACHE_ROOTS`, `AUR_TEST_SYSTEMD_SYSTEM_DIR`, and `AUR_DEPS_SEARCH_PATHS`.
- fishcheck in CI is installed only for the lint job (`tools/fishcheck`; see `.github/workflows/ci.yml`).
- CI jobs path-filter to Fish/code/list/packaging changes (docs-only PRs skip CI; weekly schedule still runs full).

## Pull requests

Use the PR template checklist. CI must pass (lint + Ubuntu/Arch tests). One logical change per PR when possible.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability disclosure vs public IOC reports.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
