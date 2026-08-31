#!/usr/bin/env bash
set -euo pipefail

browser="$(command -v google-chrome || command -v chromium || true)"
magick="$(command -v magick || true)"
identify_bin="$(command -v identify || true)"
compare_bin="$(command -v compare || true)"
if [[ -z "$browser" || ( -z "$magick" && ( -z "$identify_bin" || -z "$compare_bin" ) ) ]]; then
  echo "site visual check requires Chrome or Chromium and ImageMagick" >&2
  exit 1
fi

identify_image() {
  if [[ -n "$magick" ]]; then
    "$magick" identify "$@"
  else
    "$identify_bin" "$@"
  fi
}

compare_image() {
  if [[ -n "$magick" ]]; then
    "$magick" compare "$@"
  else
    "$compare_bin" "$@"
  fi
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
baseline_dir="$root/tests/site-visual"
actual_dir="$(mktemp -d)"
port="${SITE_VISUAL_PORT:-4174}"
server_pid=""

cleanup() {
  [[ -z "$server_pid" ]] || kill "$server_pid" 2>/dev/null || true
  rm -rf "$actual_dir"
}
trap cleanup EXIT

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root/site" \
  >"$actual_dir/server.log" 2>&1 &
server_pid="$!"
for _ in {1..20}; do
  curl -fsS "http://127.0.0.1:$port/" >/dev/null && break
  sleep 0.25
done
curl -fsS "http://127.0.0.1:$port/" >/dev/null

viewports=(1440x1100 900x1100 390x844 320x800)
for viewport in "${viewports[@]}"; do
  output="$actual_dir/$viewport.png"
  "$browser" \
    --headless \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --force-prefers-reduced-motion \
    --font-render-hinting=none \
    --window-size="${viewport/x/,}" \
    --screenshot="$output" \
    "http://127.0.0.1:$port/" >/dev/null 2>&1

  dimensions="$(identify_image -format '%wx%h' "$output")"
  [[ "$dimensions" == "$viewport" ]] || {
    echo "$viewport capture has dimensions $dimensions" >&2
    exit 1
  }
done

if [[ "${UPDATE_SITE_VISUALS:-0}" == 1 ]]; then
  mkdir -p "$baseline_dir"
  cp "$actual_dir"/*.png "$baseline_dir/"
  echo "updated site visual baselines"
  exit 0
fi

threshold="${SITE_VISUAL_RMSE_MAX:-0.03}"
for viewport in "${viewports[@]}"; do
  baseline="$baseline_dir/$viewport.png"
  [[ -s "$baseline" ]] || { echo "missing visual baseline: $baseline" >&2; exit 1; }
  metric="$(compare_image -metric RMSE "$baseline" "$actual_dir/$viewport.png" null: 2>&1 || true)"
  normalized="$(sed -n 's/.*(\([^)]*\)).*/\1/p' <<<"$metric")"
  awk -v actual="$normalized" -v max="$threshold" 'BEGIN { exit !(actual <= max) }' || {
    echo "$viewport visual RMSE $normalized exceeds $threshold" >&2
    exit 1
  }
  echo "$viewport visual RMSE $normalized"
done
