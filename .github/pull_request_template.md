## Summary

<!-- What does this PR change and why? -->

## Type

Conventional Commits type for the title (`type(scope): summary`):

- [ ] `fix` — bug fix
- [ ] `feat` — new campaign / IOC / capability
- [ ] `refactor` — internal restructure (same behavior)
- [ ] `docs` — documentation only
- [ ] `test` — tests only
- [ ] `ci` / `build` / `chore` — tooling, deps, hygiene
- [ ] `perf` / `style` / `revert` — other

## Checklist

- [ ] Commit/PR title follows Conventional Commits ([CONTRIBUTING.md](../CONTRIBUTING.md))
- [ ] `cargo test --locked` passes locally (skip if docs-only)
- [ ] `cargo fmt --check` and strict clippy pass locally
- [ ] User-facing changes update [`CHANGELOG.md`](../CHANGELOG.md)
- [ ] Release-worthy changes bump [`VERSION`](../VERSION) to match CHANGELOG
- [ ] New campaigns: `data/docs/{slug}.md` + entry in `data/docs/sources.md` (not duplicated URLs in README)
- [ ] No secrets, tokens, or live credential data in fixtures or PR description

## Test plan

<!-- Commands run, exit codes observed, or "docs only" -->
