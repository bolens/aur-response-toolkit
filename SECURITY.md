# Security policy

[Documentation](docs/README.md)

## Reporting vulnerabilities in this toolkit

If you find a security issue in **aur-response-toolkit** itself, report it
privately. Examples include logic that hides compromise, unsafe recovery
actions, and credential leaks in reports.

1. Open a [GitHub Security Advisory](https://github.com/bolens/aur-response-toolkit/security/advisories/new).
2. If you cannot use advisories, email the repository owner through the contact
   on the owner's GitHub profile.

Do not open a public issue for an exploitable toolkit bug before a fix is
available.

Include:

- Affected version (`aur-response --version` or `cat VERSION`)
- Distro and Rust build/package version
- Steps to reproduce
- Impact (what an attacker or a compromised scan could cause)
- Suggested fix if you have one

The maintainer aims to acknowledge a report within a few days and release a
confirmed fix as soon as practical.

## Reporting new AUR campaigns, IOCs, or false positives

Use public issues for new campaign data and false positives. These reports are
not private disclosures about the toolkit.

| Type | Template |
|------|----------|
| New campaign or package list update | [Campaign / IOC](.github/ISSUE_TEMPLATE/campaign.yml) |
| Benign package flagged incorrectly | [False positive](.github/ISSUE_TEMPLATE/false_positive.yml) |
| General bugs | [Bug report](.github/ISSUE_TEMPLATE/bug_report.yml) |

Cite the upstream advisory URL, SHA256, and date window. Do not paste live
secrets, stolen credentials, or full shell histories. Redact tokens and paths.

## What this project is not

- **Not** an official Arch Linux or AUR project.
- **Not** a substitute for rotating credentials after confirmed compromise.
- **Not** a managed malware-analysis or incident-response service. You run the
  detection and recovery tools locally.

## Safe handling on potentially compromised hosts

Run scans from a known-clean environment when possible. Reports under `reports/`
or `~/.local/share/aur-response/reports/` can contain paths and findings near
credentials. Treat the reports as sensitive. Run
`aur-response recovery remove-packages --dry-run` before you use `--force`.

### User config is trusted code

Native `aur-response` uses non-executable `config.toml`. The migration command
parses only documented legacy assignments and never evaluates the source file.

## Supported versions

Security fixes apply to the latest release on `main`. Older tags receive
backports only for critical issues.
