#!/usr/bin/env bash
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

printf '3.4.5\n' > "$root/VERSION"
printf '%s  native.tar.gz\n' "$(printf '0%.0s' {1..64})" > "$root/native.sha256"
printf '%s  source.tar.gz\n' "$(printf '1%.0s' {1..64})" > "$root/source.sha256"
cp site/index.html "$root/index.html"

python3 scripts/ci/build-site-release-metadata.py \
  "$root/VERSION" "$root/native.sha256" "$root/source.sha256" "$root/release.json" \
  "$root/index.html"

python3 - "$root/release.json" <<'PY'
import json
import sys

metadata = json.load(open(sys.argv[1], encoding="utf-8"))
assert metadata["version"] == "3.4.5"
assert metadata["native_sha256"] == "0" * 64
assert metadata["source_sha256"] == "1" * 64
assert metadata["native_url"].endswith("aur-response-toolkit-3.4.5-linux-x86_64.tar.gz")
PY

grep -F '<span id="release-version">v3.4.5</span>' "$root/index.html"
grep -F "$(printf '0%.0s' {1..64})" "$root/index.html"
grep -F 'data-release-state="ready"' "$root/index.html"

printf 'not-a-checksum\n' > "$root/native.sha256"
if python3 scripts/ci/build-site-release-metadata.py \
  "$root/VERSION" "$root/native.sha256" "$root/source.sha256" "$root/release.json"; then
  echo "invalid checksum was accepted" >&2
  exit 1
fi

echo "ok: site release metadata is derived and validated"
