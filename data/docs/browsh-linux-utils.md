# browsh-bin and linux-utils incident

Opt-in campaign for the malicious `browsh-bin` update on **May 27, 2026**.

## Incident

The update introduced an npm dependency named `linux-utils`. The package's
preinstall path executed an ELF blob embedded under `src/system/index.mjs`.
Arch staff confirmed that the AUR commit was malicious, reverted it, and
suspended the uploader.

The primary source is the
[aur-general report about the malicious browsh-bin update](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/D2SHEO53A7V334VKQZ2SCHS37MHSBNHU/).

## Toolkit coverage

| Area | Coverage |
|---|---|
| Package | `browsh-bin` |
| Window | May 27, 2026 |
| CLI | `--browsh-linux-utils`; `scan packages/timeline browsh-linux-utils` |
| Configuration | `AUR_ENABLE_BROWSH_LINUX_UTILS`, `AUR_BROWSH_LINUX_UTILS_LIST_FILE`, `AUR_BROWSH_LINUX_UTILS_URL` |
| Exit policy | `--fail-on browsh-linux-utils` |
| Artifacts | `linux-utils`, `index.mjs`, and embedded ELF magic in npm/cache paths |
| JSON | `browsh_linux_utils_*`, `browsh_linux_utils_list_sha256` |

## Response

Preserve the helper and npm caches before removing `browsh-bin`. Determine
whether npm lifecycle scripts ran. Treat an executed embedded ELF as evidence
of compromise unless analysis disproves it.
