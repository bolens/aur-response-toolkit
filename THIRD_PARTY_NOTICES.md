# Third-party notices

## License scope

The root MIT license covers original material authored by bolens. It does not
replace third-party licenses, copyright notices, trademarks, or service terms.
Imported and modified third-party material keeps its applicable upstream terms.

## Existing source and font notices

Retain [source attribution](data/docs/third-party-notices.md) and the DejaVu
license at `site/fonts/LICENSE-DejaVu.txt` with the fonts. External threat reports
and fetched indicator lists retain their own terms. A public source link is not
an unrestricted license for its report text or data.

## GitHub Spec Kit

Imported `.specify/scripts/`, `.specify/templates/`, and
`.agents/skills/speckit-*` integration files retain GitHub's MIT copyright and
permission notice in [.specify/LICENSE](.specify/LICENSE). Include it when
copying these files. Project-authored memory documents have separate ownership.

## Dependency inputs

Dependency declarations are recorded in:

- `Cargo.toml`

## Redistribution

Keep applicable full license and copyright notices with copied source and
bundled dependencies, including minified JavaScript and compiled executables.
Use the exact dependency versions selected by the lockfile or build. Preserve
Apache NOTICE material and satisfy copyleft source requirements where they
apply. Development-only tools and separately installed programs keep their own
terms but are not automatically part of a distributed application.

This source inventory is not proof that every historical release, external
asset, fetched dataset, or built container has satisfied its license obligations.

Full [dependency license texts](THIRD_PARTY_LICENSES.txt) accompany this source.

## Updating dependencies

When a lockfile or module version changes, refresh `THIRD_PARTY_LICENSES.txt`
from those exact package sources and review new license terms and NOTICE files.
Verify that source archives, compiled archives, native packages, containers, and
served browser bundles retain the notices for what they actually distribute.
Do not copy notice inventories between branches with different dependency locks.
