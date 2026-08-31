#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/aur-response-packaging-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/scripts/ci" "$work/packaging/arch"
cp "$root/VERSION" "$work/VERSION"
cp "$root/scripts/ci/update-release-packaging.py" "$work/scripts/ci/"
cp "$root/packaging/arch/PKGBUILD" "$work/packaging/arch/"
cp "$root/packaging/arch/.SRCINFO" "$work/packaging/arch/"

version="$(cat "$work/VERSION")"
checksum="$(printf 'ab%.0s' {1..32})"
(
  cd "$work"
  python3 scripts/ci/update-release-packaging.py "$version" "$checksum"
  grep -Fx "sha256sums=('$checksum')" packaging/arch/PKGBUILD
  grep -Fx $'\tsha256sums = '"$checksum" packaging/arch/.SRCINFO

  if python3 scripts/ci/update-release-packaging.py "$version" "not-a-checksum"; then
    echo "updater accepted an invalid checksum" >&2
    exit 1
  fi
  if python3 scripts/ci/update-release-packaging.py "0.0.0" "$checksum"; then
    echo "updater accepted a mismatched version" >&2
    exit 1
  fi
)

echo "ok: release packaging updater rejects invalid input and updates both manifests"
