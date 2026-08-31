#!/usr/bin/env python3
"""Update Arch package metadata with a tagged source checksum."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


HEX_SHA256 = re.compile(r"[0-9a-f]{64}")


def replace_one(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"expected one match in {path}: {pattern}")
    path.write_text(updated, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("source_sha256")
    args = parser.parse_args()

    checksum = args.source_sha256.lower()
    if not HEX_SHA256.fullmatch(checksum) or checksum == "0" * 64:
        raise SystemExit(f"invalid source_sha256: {args.source_sha256}")

    version = Path("VERSION").read_text(encoding="utf-8").strip()
    if args.version != version:
        raise SystemExit(f"release version {args.version} does not match VERSION {version}")

    pkgbuild = Path("packaging/arch/PKGBUILD")
    srcinfo = Path("packaging/arch/.SRCINFO")
    pkgbuild_text = pkgbuild.read_text(encoding="utf-8")
    if not re.search(rf"^pkgver={re.escape(version)}$", pkgbuild_text, re.MULTILINE):
        raise SystemExit(f"{pkgbuild} pkgver does not match VERSION {version}")

    replace_one(
        pkgbuild,
        r"^sha256sums=\((?:'[0-9a-fA-F]{64}'|'SKIP')\)$",
        f"sha256sums=('{checksum}')",
    )
    replace_one(
        srcinfo,
        r"^\s*sha256sums = (?:[0-9a-fA-F]{64}|SKIP)$",
        f"\tsha256sums = {checksum}",
    )


if __name__ == "__main__":
    main()
