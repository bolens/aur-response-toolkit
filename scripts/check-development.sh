#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash .githooks/pre-push
python3 -m unittest discover -s tests -p test_development_container.py
ruff check scripts/development-container.py tests/test_development_container.py
shellcheck scripts/check-development.sh
markdownlint-cli2 'docs/development-environments.md' 'specs/002-development-environments/*.md'
