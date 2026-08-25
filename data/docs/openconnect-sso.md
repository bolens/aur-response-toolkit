# OpenConnect SSO validator incident

Opt-in campaign for the coordinated validator-loader wave that began with the
malicious `openconnect-sso` AUR update on **July 29, 2026** and continued into
**August 2, 2026**.

## Incident

An orphaned `openconnect-sso` package was adopted and changed to include a
binary named `validator`, which the package build executed with `sudo`. The
aur-general reports identify commit `9d10778...` as the suspicious change.

Primary source:
[aur-general — Suspicious package update: openconnect-sso](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/latest?count=25).

## Toolkit coverage

| Area | Coverage |
|---|---|
| Packages | 203 bundled names: the 202-package confirmed corpus plus the initial `openconnect-sso` report |
| Window | July 29–August 2, 2026 |
| CLI | `--openconnect-sso`; `scan packages/timeline openconnect-sso` |
| Configuration | `AUR_ENABLE_OPENCONNECT_SSO`, `AUR_OPENCONNECT_SSO_LIST_FILE`, `AUR_OPENCONNECT_SSO_URL` |
| Exit policy | `--fail-on openconnect-sso` |
| Heuristics | Benign-looking 43,624/43,640-byte ELF loaders, privileged execution, and loader hashes |
| Persistence | `/dev/shm/.agent.bin`, dot-named systemd services, cron, linger, and Tor disguised as `dbus-daemon` |
| JSON | `openconnect_sso_*`, `openconnect_sso_list_sha256` |

An install outside the bounded date is still reported at lower confidence. Use
`--all-time` when investigating an uncertain clock or incomplete log history.

## Response

Remove the affected package, preserve its package/build cache for analysis,
inspect privileged-execution logs, and rotate credentials available to the
user or root process after establishing the exposure boundary.

Technical sources reviewed without executing samples:

- [Stage-one static analysis](https://gist.github.com/ysf/502a324ff301d0c738e8ae011272fd59)
- [Stage-two static analysis](https://gist.github.com/ysf/57850cdee152da066ac51c07a452e883)
- [202-package campaign review](https://gist.github.com/Firstp1ck/3ea306410a8894d28806a1629c67e825)
- [Arch community discovery thread](https://www.reddit.com/r/archlinux/comments/1v9scc5/seemingly_malicious_aur_package_found_where_to/)
- [Arch community 200-package follow-up](https://www.reddit.com/r/archlinux/comments/1vaxtcs/another_wave_200_malicous_aur_packages_adoptions/)

The bundled corpus snapshot was retrieved on 2026-08-24. Reports record its
SHA-256, source identifier, retrieval date, and the version/hash of the IOC
registry used for the scan.
