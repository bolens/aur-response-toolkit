#!/usr/bin/env bash
# Build only. Publication credentials are deliberately absent from this step.
set -euo pipefail
[[ "$CI_FORGE_TYPE" = github && "$CI_REPO" = "bolens/aur-response-toolkit" && "$CI_PIPELINE_EVENT" = tag ]]
[[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$(git rev-parse HEAD)" = "$CI_COMMIT_SHA" ]]
[[ -z "$(git status --porcelain --untracked-files=no)" ]]
mkdir -p .woodpecker-out
[[ ! -e .woodpecker-out/release ]]
mkdir .woodpecker-out/release
VERSION="${CI_COMMIT_TAG#v}"
[[ "$(cat VERSION)" = "$VERSION" ]]
cargo build --release --locked
bundle="aur-response-toolkit-${VERSION}-linux-x86_64"
mkdir ".woodpecker-out/$bundle"
install -m755 target/release/aur-response ".woodpecker-out/$bundle/aur-response"
install -m644 README.md config.toml.example LICENSE THIRD_PARTY_LICENSES.txt THIRD_PARTY_NOTICES.md ".woodpecker-out/$bundle/"
cp -R data ".woodpecker-out/$bundle/data"
tar -C .woodpecker-out -czf ".woodpecker-out/release/$bundle.tar.gz" "$bundle"
(cd .woodpecker-out/release && sha256sum "$bundle.tar.gz" > "$bundle.tar.gz.sha256")
curl --fail --location --retry 3 --output ".woodpecker-out/release/aur-response-toolkit-${VERSION}-source.tar.gz" "https://github.com/$CI_REPO/archive/refs/tags/$CI_COMMIT_TAG.tar.gz"
(cd .woodpecker-out/release && sha256sum "aur-response-toolkit-${VERSION}-source.tar.gz" > "aur-response-toolkit-${VERSION}-source.tar.gz.sha256")
awk -v ver="$VERSION" '$0 ~ "^## " ver "$" { found=1; next } found && /^## / { exit } found { print }' CHANGELOG.md > .woodpecker-out/release-notes.md
test -s .woodpecker-out/release-notes.md
python3 - <<'MANIFEST'
import hashlib, json, os
from pathlib import Path
out = Path('.woodpecker-out/release')
provenance = {
    '_type': 'https://in-toto.io/Statement/v1',
    'subject': [{'name': f.name, 'digest': {'sha256': hashlib.sha256(f.read_bytes()).hexdigest()}}
                for f in sorted(out.iterdir())],
    'predicateType': 'https://slsa.dev/provenance/v1',
    'predicate': {'buildDefinition': {
        'buildType': 'https://woodpecker-ci.org/ci',
        'externalParameters': {'repository': os.environ['CI_REPO'], 'tag': os.environ['CI_COMMIT_TAG']},
        'resolvedDependencies': [{'uri': 'git+https://github.com/' + os.environ['CI_REPO'],
                                  'digest': {'gitCommit': os.environ['CI_COMMIT_SHA']}}]},
        'runDetails': {'builder': {'id': os.environ['CI_SYSTEM_URL']},
                       'metadata': {'invocationId': os.environ['CI_PIPELINE_URL']}}},
}
(out / 'woodpecker-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
with (out / 'SHA256SUMS').open('w') as sums:
    for f in sorted(out.iterdir()):
        if f.name != 'SHA256SUMS':
            sums.write(hashlib.sha256(f.read_bytes()).hexdigest() + '  ' + f.name + '\n')
MANIFEST
(cd .woodpecker-out/release && sha256sum --check --strict SHA256SUMS)
python3 scripts/ci/woodpecker-publish.py manifest
