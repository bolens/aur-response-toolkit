#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
font_root="${DEJAVU_FONT_DIR:-/usr/share/fonts/TTF}"
unicode_ranges="U+0000-00FF,U+2000-206F,U+2190-21FF"

command -v pyftsubset >/dev/null || {
  echo "build-site-fonts.sh requires fonttools and Brotli support" >&2
  exit 1
}

pyftsubset "$font_root/DejaVuSans.ttf" \
  --output-file="$root/site/fonts/ToolkitSans.woff2" \
  --flavor=woff2 \
  --unicodes="$unicode_ranges" \
  --layout-features='*' \
  --no-hinting

pyftsubset "$font_root/DejaVuSansMono.ttf" \
  --output-file="$root/site/fonts/ToolkitMono.woff2" \
  --flavor=woff2 \
  --unicodes="$unicode_ranges" \
  --layout-features='*' \
  --no-hinting

echo "updated subsetted site fonts"
