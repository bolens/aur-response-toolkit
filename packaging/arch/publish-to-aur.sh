#!/usr/bin/env bash
# Sync packaging/arch/ to a local AUR package clone and push.
#
# Prerequisites:
#   - AUR account with SSH key: https://aur.archlinux.org/account/
#   - Clone once: git clone ssh://aur@aur.archlinux.org/aur-response-toolkit.git
#
# Usage:
#   AUR_DIR=~/aur/aur-response-toolkit ./publish-to-aur.sh
#   AUR_DIR=~/aur/aur-response-toolkit ./publish-to-aur.sh --push

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
aur_dir="${AUR_DIR:-$HOME/aur/aur-response-toolkit}"
do_push=false

for arg in "$@"; do
  case "$arg" in
    --push) do_push=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$aur_dir/.git" ]]; then
  echo "AUR clone not found at: $aur_dir" >&2
  echo "Create it with:" >&2
  echo "  mkdir -p $(dirname "$aur_dir")" >&2
  echo "  git clone ssh://aur@aur.archlinux.org/aur-response-toolkit.git \"$aur_dir\"" >&2
  exit 1
fi

files=(
  PKGBUILD
  .SRCINFO
  aur-response-toolkit.install
  fhs-writable-state.patch
)

for f in "${files[@]}"; do
  install -Dm644 "$here/$f" "$aur_dir/$f"
done

(
  cd "$aur_dir"
  if git diff --quiet && git diff --cached --quiet; then
    echo "AUR clone already up to date."
    exit 0
  fi
  git add "${files[@]}"
  git status --short
  pkgver="$(grep -E '^pkgver=' PKGBUILD | cut -d= -f2 | tr -d "'")"
  pkgrel="$(grep -E '^pkgrel=' PKGBUILD | cut -d= -f2 | tr -d "'")"
  git commit -m "aur-response-toolkit ${pkgver}-${pkgrel}"
  if $do_push; then
    git push origin master
    echo "Pushed to AUR."
  else
    echo "Committed locally. Push with: (cd \"$aur_dir\" && git push origin master)"
    echo "Or rerun: AUR_DIR=\"$aur_dir\" $0 --push"
  fi
)
