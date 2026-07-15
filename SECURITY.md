# Security policy

## Reporting vulnerabilities in this toolkit

If you find a security issue in **aur-response-toolkit** itself (logic that could hide compromise, unsafe recovery actions, credential leaks in reports, etc.), please report it responsibly:

1. **Preferred:** Open a [GitHub Security Advisory](https://github.com/bolens/aur-response-toolkit/security/advisories/new) (private disclosure).
2. **Alternative:** Email the repository owner via GitHub profile contact if you cannot use advisories.

Please do **not** open a public issue for exploitable toolkit bugs until a fix is available.

Include:

- Affected version (`aur-response --version`, `fish run.fish --version`, or `cat VERSION`)
- Distro and Fish version
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

Run scans from a known-clean environment when possible. Reports under `reports/` (or `~/.local/share/aur-response/reports/` on FHS installs) may contain paths and credential-adjacent findings — treat them as sensitive. Review `recovery/remove-packages.fish` output before `--force`.

### User config is trusted code

If `~/.config/aur-response/config.fish` (or `$XDG_CONFIG_HOME/aur-response/config.fish`) exists, every scan **sources it as Fish** before running. Treat that file like shell rc: only edit it yourself, and on a compromised host assume an attacker could have changed overrides (paths, enable flags, search roots). Prefer reviewing or removing the config when triaging a live incident from a clean environment.

## Supported versions

Security fixes are applied to the latest release on `main`. Older tags may not receive backports unless the issue is critical.
