# VS Code for aur-response-toolkit

[Documentation](../docs/README.md)

Open this repository as a folder, or add it as a folder in a multi-root workspace.
Install the recommendations from the Extensions view. Use **Tasks: Run Task** for
the commands below. Tasks run from this repository unless they state another directory.

Use the tool versions documented by the repository. Launch VS Code from the
prepared development shell, or reopen in the existing dev container when available.
Extension recommendations do not install command-line dependencies.

| Task | Command |
| --- | --- |
| cargo build | `cargo build --locked` |
| cargo test | `cargo test --locked` |
| cargo fmt check | `cargo fmt --check` |
| cargo clippy | `cargo clippy --all-targets --locked -- -D warnings` |
| Check diff whitespace | `git diff --check` |

Debug configurations are available in **Run and Debug**. Choose a test or help
configuration for development. The selected-file configurations run the selected
script, so select a test or an intended entry point.
