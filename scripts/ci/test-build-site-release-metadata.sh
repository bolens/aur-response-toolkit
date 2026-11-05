#!/usr/bin/env bash
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

printf '3.4.5\n' > "$root/VERSION"
printf '%s  native.tar.gz\n' "$(printf '0%.0s' {1..64})" > "$root/native.sha256"
printf '%s  source.tar.gz\n' "$(printf '1%.0s' {1..64})" > "$root/source.sha256"
cp -R site "$root/source-site"
cp -R "$root/source-site" "$root/rendered-site"

python3 scripts/ci/build-site-release-metadata.py \
  "$root/VERSION" "$root/native.sha256" "$root/source.sha256" "$root/rendered-site/release.json" \
  "$root/rendered-site/index.html"

python3 - "$root/rendered-site/release.json" <<'PY'
import json
import sys

metadata = json.load(open(sys.argv[1], encoding="utf-8"))
assert metadata["version"] == "3.4.5"
assert metadata["native_sha256"] == "0" * 64
assert metadata["source_sha256"] == "1" * 64
assert metadata["native_url"].endswith("aur-response-toolkit-3.4.5-linux-x86_64.tar.gz")
PY

grep -F '<span id="release-version">v3.4.5</span>' "$root/rendered-site/index.html"
grep -F "$(printf '0%.0s' {1..64})" "$root/rendered-site/index.html"
grep -F 'data-release-state="ready"' "$root/rendered-site/index.html"

# Generated release links are valid artifacts, but must never enter source HTML.
CHECK_EXTERNAL_LINKS=0 SOURCE_SITE_DIR="$root/source-site" SITE_DIR="$root/rendered-site" \
  python3 scripts/ci/check-site-links.py
cmp site/index.html "$root/source-site/index.html"
if CHECK_EXTERNAL_LINKS=0 SOURCE_SITE_DIR="$root/rendered-site" SITE_DIR="$root/rendered-site" \
  python3 scripts/ci/check-site-links.py 2> "$root/source-guard.log"; then
  echo "rendered release URLs were accepted as source HTML" >&2
  exit 1
fi
grep -F 'source HTML hardcodes a release version' "$root/source-guard.log"

printf 'not-a-checksum\n' > "$root/native.sha256"
if python3 scripts/ci/build-site-release-metadata.py \
  "$root/VERSION" "$root/native.sha256" "$root/source.sha256" "$root/rendered-site/release.json"; then
  echo "invalid checksum was accepted" >&2
  exit 1
fi

echo "ok: site release metadata is derived and validated"
