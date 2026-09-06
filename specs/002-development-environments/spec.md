# AUR toolkit development environment

Provide locked Rust/compiler and repository-validation tools for the existing
fixture-backed CLI, configuration, report, and recovery contracts. Package sources
and malicious fixtures remain data; development checks must never execute them
or remediate the workstation.

Support native Linux/macOS tooling and source-free Docker, rootless Podman, and
Apple container adapters. Preserve caller ownership, argument boundaries, and
failure status. Native fixture checks do not establish real Arch package-manager
integration; keep the existing Arch CI gate. Apple execution requires supported
Mac hardware and a Linux Nix builder and is unavailable on this host.
