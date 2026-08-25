# xsnow worm incident

Opt-in campaign for the malicious `xsnow` and `xsnow-bin` AUR updates reported
on **August 23, 2026** and remediated by Arch staff the same day.

## Incident

The updates referenced dot-prefixed install scriptlets that pacman would run as
root. The scriptlets downloaded an executable named `systemmanager` over Tor
and attempted to propagate by pushing malicious changes to other AUR package
repositories accessible to the affected user.

Primary source:
[aur-general — Malicious package update - xsnow and xsnow-bin](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/FPT525XVV2DL2P437KPHTADV3KJINORN/).
Arch staff confirmed that both packages were reverted and the uploader was
suspended. A follow-up scan of all AUR packages declaring `install=` found no
additional instance resembling this worm as of August 24.

## Toolkit coverage

| Area | Coverage |
|---|---|
| Packages | `xsnow`, `xsnow-bin` |
| Observed incident | August 23, 2026 |
| Conservative scan window | August 23–24, 2026 |
| CLI | `--xsnow-worm`; `scan packages/timeline xsnow-worm` |
| Configuration | `AUR_ENABLE_XSNOW_WORM`, `AUR_XSNOW_WORM_LIST_FILE`, `AUR_XSNOW_WORM_URL` |
| Exit policy | `--fail-on xsnow-worm` |
| Heuristics | `systemmanager`, Tor onion references, and AUR push behavior in cached or installed hooks |
| Runtime/persistence | `systemmanager` and onion references in processes, cron, systemd, shell startup, and autostart entries |
| JSON | `xsnow_worm_*`, `xsnow_worm_list_sha256` |

## Response

Preserve the affected package and helper caches for analysis. If either package
was installed or upgraded in the incident window, inspect `/usr/local/bin`,
system services, scheduled jobs, and AUR repository histories. Revoke affected
AUR/SSH credentials only after preserving evidence and establishing the scope.
Package removal and credential changes remain explicit operator actions.
