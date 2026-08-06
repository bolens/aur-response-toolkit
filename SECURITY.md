# Security policy

## Reporting vulnerabilities in this toolkit

If you find a security issue in **aur-response-toolkit** itself (logic that could hide compromise, unsafe recovery actions, credential leaks in reports, etc.), please report it responsibly:

1. **Preferred:** Open a [GitHub Security Advisory](https://github.com/bolens/aur-response-toolkit/security/advisories/new) (private disclosure).
2. **Alternative:** Email the repository owner via GitHub profile contact if you cannot use advisories.

Please do **not** open a public issue for exploitable toolkit bugs until a fix is available.

Include:

- Affected version (`aur-response --version` or `cat VERSION`)
- Distro and Rust build/package version
- Steps to reproduce
- Impact (what an attacker or a compromised scan could cause)
- Suggested fix if you have one

We aim to acknowledge reports within a few days and ship fixes for confirmed issues as soon as practical.

## Reporting new AUR campaigns, IOCs, or false positives

These are **not** private security disclosures for this repo — use public issues:

| Type | Template |
|------|----------|
| New campaign or package list update | [Campaign / IOC](.github/ISSUE_TEMPLATE/campaign.yml) |
| Benign package flagged incorrectly | [False positive](.github/ISSUE_TEMPLATE/false_positive.yml) |
| General bugs | [Bug report](.github/ISSUE_TEMPLATE/bug_report.yml) |

Always cite upstream sources (advisory URL, SHA256, date window). Do not paste live secrets, stolen credentials, or full shell histories — redact tokens and paths.

## What this project is not

- **Not** an official Arch Linux or AUR project.
- **Not** a substitute for rotating credentials after confirmed compromise.
- **Not** malware analysis or incident response on behalf of users — we provide detection and recovery **scripts** you run locally.

## Safe handling on potentially compromised hosts

Run scans from a known-clean environment when possible. Reports under `reports/` (or `~/.local/share/aur-response/reports/` on FHS installs) may contain paths and credential-adjacent findings — treat them as sensitive. Review `aur-response recovery remove-packages --dry-run` before `--force`.

### User config is trusted code

Native `aur-response` uses non-executable `config.toml`. The migration command
parses only documented legacy assignments and never evaluates the source file.

## Supported versions

Security fixes are applied to the latest release on `main`. Older tags may not receive backports unless the issue is critical.
