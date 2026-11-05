#!/usr/bin/env bash
# Build in a disposable copy so validation never mutates the release source.
set -euo pipefail
mkdir -p .woodpecker-out
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git archive HEAD | tar -x -C "$work"
python3 - "$work" <<'LATEST'
import json, sys, urllib.request
from pathlib import Path
with urllib.request.urlopen('https://api.github.com/repos/bolens/aur-response-toolkit/releases/latest', timeout=30) as response:
    release = json.load(response)
(Path(sys.argv[1]) / 'latest-release.json').write_text(json.dumps(release))
LATEST
(cd "$work" && python3 scripts/render-changelog.py --name "AUR Response Toolkit" --base-url https://bolens.github.io/aur-response-toolkit/ --accent "#f4bf75" --social-image og.png --favicon favicon.png --output site/changelog/index.html
python3 - <<'METADATA'
import json, re, urllib.request
from pathlib import Path
release=json.loads(Path('latest-release.json').read_text())
tag=release['tag_name']
assert re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+',tag)
version=tag[1:]
Path('site-version').write_text(version+'\n')
names=[f'aur-response-toolkit-{version}-linux-x86_64.tar.gz.sha256', f'aur-response-toolkit-{version}-source.tar.gz.sha256']
for name in names:
    asset=next(a for a in release['assets'] if a['name']==name)
    urllib.request.urlretrieve(asset['browser_download_url'], name)
METADATA
version=$(cat site-version)
python3 scripts/ci/build-site-release-metadata.py site-version "aur-response-toolkit-$version-linux-x86_64.tar.gz.sha256" "aur-response-toolkit-$version-source.tar.gz.sha256" site/release.json site/index.html
SITE_DIR="$PWD/site" python3 scripts/ci/check-site-accessibility.py
CHECK_EXTERNAL_LINKS=1 SITE_DIR="$PWD/site" python3 scripts/ci/check-site-links.py
# Chromium is confined to this unprivileged Docker job; no host sandbox/socket access.
mkdir -p browser-bin
printf '#!/bin/sh\nexec /usr/bin/chromium --no-sandbox "$@"\n' > browser-bin/google-chrome
chmod +x browser-bin/google-chrome
PATH="$PWD/browser-bin:$PATH" SITE_DIR="$PWD/site" bash scripts/ci/check-site-visual.sh)
rm -rf .woodpecker-out/site
cp -R "$work/site" .woodpecker-out/site
