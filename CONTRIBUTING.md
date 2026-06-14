# Contributing

Thanks for helping improve incident response for AUR supply-chain threats.

## Before you start

1. Read [`data/docs/sources.md`](data/docs/sources.md) for how campaigns, lists, and docs are organized.
2. Run the test suite and linter locally:

```fish
fish tests/run-all.fish
fish lint.fish
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

- Fish scripts use `aur_*` helpers from `lib/` — avoid raw `grep`, `find`, `curl` at call sites.
- Scripts live under `scripts/{check,scan,audit,recovery}/` and bootstrap via `scripts/_init.fish`.
- User-facing changes: update [`CHANGELOG.md`](CHANGELOG.md) under `## Unreleased` or the next version section.
- User-facing release: bump [`VERSION`](VERSION) to match CHANGELOG.

## Adding a new campaign (outline)

1. Bundled list: `data/lists/{slug}-pkgs.txt`
2. Provenance doc: `data/docs/{slug}.md` (URLs, date window, license notes)
3. Index entry in `data/docs/sources.md`
4. Check script: `scripts/check/{slug}-pkgs.fish`
5. Timeline script: `scripts/scan/{slug}-timeline.fish`
6. Opt-in flag on `run.fish` and config keys in `config.fish.example`
7. JSON summary fields in `lib/reports.fish`
8. Removal support in `scripts/recovery/remove-packages.fish --list {slug}`
9. Tests: fixtures in `tests/fixtures/`, suites under `tests/unit/` and `tests/integration/`
10. README: short comparison table (keep detailed IOC refs in `data/docs/`)

## Tests

- `tests/run-all.fish` discovers `test-*.fish` under `tests/unit/` and `tests/integration/`.
- Use fixtures in `tests/fixtures/` — never point tests at a live system pacman db.
- Integration tests should set isolated temp dirs via `tests/support/test-utils.fish`.

## Pull requests

Use the PR template checklist. CI must pass (Ubuntu + Arch jobs). One logical change per PR when possible.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability disclosure vs public IOC reports.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
