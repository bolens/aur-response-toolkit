#!/usr/bin/env bash
# Thin wrapper for users whose login shell is not fish.
# Preserves argv and exit code via exec — no argument translation needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec fish "$ROOT/run.fish" "$@"
