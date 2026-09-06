# Implementation plan

Pin devenv/nixpkgs and supply Rust, Cargo, Clippy, rustfmt, a C compiler, GNU tools,
compressed-log utilities, Python, and repository validators. Wrap the existing
pre-push gate, including the release build and site-metadata fixtures, then add
adapter regressions and tooling/documentation lint.

Use filtered native Linux/macOS and real Docker CI with cancellation and a stable
result gate. Preserve existing Rust/Arch checks, campaign data, manifests, and
site content. Validate native and Podman paths before a protected PR, then verify
main and clean the feature. Environment tooling alone needs no product release.
