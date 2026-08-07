# OpenConnect SSO validator incident

Opt-in campaign for the malicious `openconnect-sso` AUR update reported on
**July 29, 2026**.

## Incident

An orphaned `openconnect-sso` package was adopted and changed to include a
binary named `validator`, which the package build executed with `sudo`. The
aur-general reports identify commit `9d10778...` as the suspicious change.

Primary source:
[aur-general — Suspicious package update: openconnect-sso](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/latest?count=25).

## Toolkit coverage

| Area | Coverage |
|---|---|
| Package | `openconnect-sso` |
| Window | July 29, 2026 |
| CLI | `--openconnect-sso`; `scan packages/timeline openconnect-sso` |
| Configuration | `AUR_ENABLE_OPENCONNECT_SSO`, `AUR_OPENCONNECT_SSO_LIST_FILE`, `AUR_OPENCONNECT_SSO_URL` |
| Exit policy | `--fail-on openconnect-sso` |
| Heuristics | `validator` artifacts and install hooks that invoke it with `sudo` |
| JSON | `openconnect_sso_*`, `openconnect_sso_list_sha256` |

An install outside the bounded date is still reported at lower confidence. Use
`--all-time` when investigating an uncertain clock or incomplete log history.

## Response

Remove the affected package, preserve its package/build cache for analysis,
inspect privileged-execution logs, and rotate credentials available to the
user or root process after establishing the exposure boundary.
