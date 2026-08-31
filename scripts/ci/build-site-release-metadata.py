#!/usr/bin/env python3
"""Build release metadata for the static user guide without executing package files."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SHA256_LINE = re.compile(r"^([0-9a-f]{64})(?:\s+.+)?$")
VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def read_version(path: Path) -> str:
    version = path.read_text(encoding="utf-8").strip()
    if not VERSION.fullmatch(version):
        raise ValueError(f"invalid VERSION: {version!r}")
    return version


def read_checksum(path: Path) -> str:
    first_line = path.read_text(encoding="utf-8").splitlines()[0].strip()
    match = SHA256_LINE.fullmatch(first_line)
    if not match:
        raise ValueError(f"invalid SHA-256 file: {path}")
    return match.group(1)


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "usage: build-site-release-metadata.py VERSION NATIVE_SHA SOURCE_SHA OUTPUT",
            file=sys.stderr,
        )
        return 2

    version_path, native_path, source_path, output_path = map(Path, sys.argv[1:])
    try:
        version = read_version(version_path)
        native_sha256 = read_checksum(native_path)
        source_sha256 = read_checksum(source_path)
    except (IndexError, OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    release_root = f"https://github.com/bolens/aur-response-toolkit/releases/download/v{version}"
    native_name = f"aur-response-toolkit-{version}-linux-x86_64.tar.gz"
    metadata = {
        "version": version,
        "native_sha256": native_sha256,
        "source_sha256": source_sha256,
        "release_url": f"https://github.com/bolens/aur-response-toolkit/releases/tag/v{version}",
        "native_url": f"{release_root}/{native_name}",
        "native_checksum_url": f"{release_root}/{native_name}.sha256",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
