#!/usr/bin/env python3
"""Build release metadata for the static user guide without executing package files."""

from __future__ import annotations

import json
import re
import sys
from html import escape
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


def replace_element_text(document: str, element_id: str, value: str) -> str:
    pattern = re.compile(
        rf'(<(?P<tag>[a-z0-9]+)\b[^>]*\bid="{re.escape(element_id)}"[^>]*>)[^<]*(</(?P=tag)>)',
        re.IGNORECASE,
    )
    document, count = pattern.subn(rf"\g<1>{escape(value)}\g<3>", document)
    if count != 1:
        raise ValueError(f"expected one HTML element with id={element_id!r}")
    return document


def replace_link(document: str, element_id: str, value: str) -> str:
    element = re.compile(
        rf'<a\b[^>]*\bid="{re.escape(element_id)}"[^>]*>', re.IGNORECASE
    )
    match = element.search(document)
    if match is None:
        raise ValueError(f"expected one HTML link with id={element_id!r}")
    tag, count = re.subn(r'href="[^"]*"', f'href="{escape(value, quote=True)}"', match.group())
    if count != 1:
        raise ValueError(f"expected one href on HTML link with id={element_id!r}")
    return document[: match.start()] + tag + document[match.end() :]


def render_index(path: Path, metadata: dict[str, str]) -> None:
    document = path.read_text(encoding="utf-8")
    document = replace_element_text(document, "release-version", f"v{metadata['version']}")
    document = replace_element_text(document, "native-checksum", metadata["native_sha256"])
    document = replace_element_text(document, "source-checksum", metadata["source_sha256"])
    document = replace_link(document, "release-download", metadata["native_url"])
    document = replace_link(document, "checksum-file", metadata["native_checksum_url"])
    document, count = re.subn(
        r'data-release-state="(?:loading|ready|error)"',
        'data-release-state="ready"',
        document,
        count=1,
    )
    if count != 1:
        raise ValueError("expected one release state in the HTML document")
    path.write_text(document, encoding="utf-8")


def main() -> int:
    if len(sys.argv) not in {5, 6}:
        print(
            "usage: build-site-release-metadata.py VERSION NATIVE_SHA SOURCE_SHA OUTPUT [INDEX_HTML]",
            file=sys.stderr,
        )
        return 2

    version_path, native_path, source_path, output_path = map(Path, sys.argv[1:5])
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
    if len(sys.argv) == 6:
        try:
            render_index(Path(sys.argv[5]), metadata)
        except (OSError, ValueError) as error:
            print(error, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
