# Development environments

[Documentation](README.md)

Install [Nix and devenv](https://devenv.sh/getting-started/), then run from this checkout:

```sh
devenv shell
repo-check
# Or run the same portable gate non-interactively:
devenv test
```

The shell supplies Rust, Cargo, Clippy, rustfmt, a C compiler, GNU tools, compressed-log utilities, curl, Linux process/socket tools, Python, and repository validators. `repo-check` runs the existing pre-push gate: formatting, strict Clippy, locked tests and release build, site-metadata fixtures, accessibility source checks, and workflow validators. It also runs the adapter regressions and tooling/documentation lint. Cargo downloads locked dependencies when they are not cached.

The tests use disposable package/configuration fixtures. They do not install packages, execute suspect package content, or apply incident recovery to this workstation. Existing Arch CI retains package-platform coverage; native fixture tests alone do not establish real Arch integration.

Commit `devenv.lock` with deliberate input updates. Local state and `devenv.local.nix` / `devenv.local.yaml` overrides are ignored. Existing Nix cache settings are used without changing daemon trust.

## Docker and Podman

Build and load the development image, then run a command with a local engine:

```sh
python3 scripts/development-container.py build podman
python3 scripts/development-container.py run podman -- bash scripts/check-development.sh
# Substitute docker for podman to use Docker.
```

Omit the command for an interactive Bash shell. The helper mounts the checkout at `/workspace`, runs with the caller's UID/GID, and uses Podman's keep-id mapping. It forwards arguments and exit status without constructing a shell command. These mounts require a local engine with access to the checkout path; remote Docker daemons need their own source transfer. Paths containing commas are rejected because they cannot be represented by this mount syntax.

The image contains tools, not checkout files. Build archives live under `.devenv/containers/` and are never uploaded by the helper.

## Apple container

[Apple container](https://github.com/apple/container) requires a supported Apple-silicon Mac. Start its runtime according to Apple's installation guide. With a Linux Nix builder configured:

```sh
python3 scripts/development-container.py build apple
python3 scripts/development-container.py run apple -- bash scripts/check-development.sh
```

The helper exports an OCI archive and uses `container image load`. Native ARM Macs target `aarch64-linux`; x86 Linux builds target `x86_64-linux`. [Building Linux images from macOS requires a Linux builder](https://devenv.sh/containers/). This workflow does not assume Apple container implements Docker Compose or Docker's daemon API.

Apple execution is not verified by Linux tests. Native macOS CI checks the Rust toolchain and fixtures; operational package-manager integration remains Arch-specific. Follow [the release playbook](../RELEASING.md) for product release and separate recovery authorization.

## Continuous integration

Woodpecker runs the locked Linux `devenv test` gate in its existing source
validation workflow without a Docker socket, host mounts or publication
credentials. The hosted Linux copy stays enabled until exact native PR and
genuine merged-main proof, followed by the separate `WOODPECKER_NIX_CI=true`
operator cutover. Native macOS and actual Docker development and editor-image checks
remain in GitHub Actions; Linux Nix validation does not require that builder.

The retained Docker export/load test reserves scratch space before installing Nix
on GitHub-hosted Linux. Its guarded helper removes only the unused
`/usr/local/lib/android` cache after rejecting symlink paths, separate filesystems
and mounts, and records `du`/`df` evidence. It requires at least 24 GiB free before
the build; the full export, Docker load and runtime tests still determine whether
the image works. The helper defaults to a read-only plan and refuses macOS,
self-hosted runners and containers. It never prunes Docker, Nix, tool caches or
checkout files. Local and self-hosted development commands do not invoke it.
