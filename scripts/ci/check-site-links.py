#!/usr/bin/env python3
"""Validate static site links, anchors, metadata, and generated release URLs."""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

BASE_PATH = "/aur-response-toolkit/"
PUBLIC_ROOT = "https://bolens.github.io/aur-response-toolkit/"
VERSIONED_RELEASE = re.compile(
    r"github\.com/bolens/aur-response-toolkit/releases/(?:download|tag)/v\d"
)


class Document(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.duplicates: set[str] = set()
        self.references: list[tuple[str, str]] = []
        self.aria_references: list[tuple[str, str]] = []
        self.canonicals: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {name: value or "" for name, value in attrs}
        element_id = values.get("id")
        if element_id:
            if element_id in self.ids:
                self.duplicates.add(element_id)
            self.ids.add(element_id)
        for attribute in ("href", "src"):
            if values.get(attribute):
                if tag == "link" and values.get("rel") in {
                    "preconnect",
                    "dns-prefetch",
                }:
                    continue
                self.references.append((attribute, values[attribute]))
        if tag == "link" and "canonical" in values.get("rel", "").split():
            self.canonicals.append(values.get("href", ""))
        for attribute in ("aria-controls", "aria-describedby", "aria-labelledby"):
            for target in values.get(attribute, "").split():
                self.aria_references.append((attribute, target))


def parse_document(path: Path) -> Document:
    document = Document()
    document.feed(path.read_text(encoding="utf-8"))
    return document


def local_target(site_dir: Path, source: Path, value: str) -> tuple[Path, str] | None:
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme or parsed.netloc or value.startswith(("data:", "mailto:", "tel:")):
        return None
    path = urllib.parse.unquote(parsed.path)
    if path.startswith(BASE_PATH):
        target = site_dir / path.removeprefix(BASE_PATH)
    elif path.startswith("/"):
        raise ValueError(f"site-root path must start with {BASE_PATH}: {value}")
    else:
        target = source.parent / path
    if not path or path.endswith("/"):
        target /= "index.html"
    target = target.resolve()
    if site_dir.resolve() not in (target, *target.parents):
        raise ValueError(f"link escapes the site directory: {value}")
    return target, parsed.fragment


def check_external(url: str) -> str | None:
    headers = {"User-Agent": "aur-response-toolkit-link-check/1"}
    for attempt in range(2):
        for method in ("HEAD", "GET"):
            request = urllib.request.Request(url, headers=headers, method=method)
            try:
                with urllib.request.urlopen(request, timeout=15) as response:
                    if 200 <= response.status < 400:
                        return None
                    return f"HTTP {response.status}"
            except urllib.error.HTTPError as error:
                if method == "HEAD" and error.code in {403, 405}:
                    continue
                if error.code in {429, 500, 502, 503, 504}:
                    break
                return f"HTTP {error.code}"
            except (TimeoutError, urllib.error.URLError) as error:
                if method == "GET":
                    failure = str(error)
        if attempt == 0:
            time.sleep(2)
    return failure if "failure" in locals() else "request failed"


def main() -> int:
    site_dir = Path(os.environ.get("SITE_DIR", "site")).resolve()
    source_site_dir = Path(os.environ.get("SOURCE_SITE_DIR", "site")).resolve()
    failures: list[str] = []
    documents: dict[Path, Document] = {}
    external_urls: set[str] = set()

    for path in sorted(site_dir.rglob("*.html")):
        document = parse_document(path)
        documents[path.resolve()] = document
        for duplicate in sorted(document.duplicates):
            failures.append(f"{path}: duplicate id #{duplicate}")
        for attribute, target in document.aria_references:
            if target not in document.ids:
                failures.append(f"{path}: {attribute} points to missing #{target}")
        relative = path.relative_to(site_dir)
        if relative == Path("index.html"):
            if document.canonicals != [PUBLIC_ROOT]:
                failures.append(f"{path}: canonical URL must be {PUBLIC_ROOT}")
        elif relative == Path("changelog/index.html"):
            expected = f"{PUBLIC_ROOT}changelog/"
            if document.canonicals != [expected]:
                failures.append(f"{path}: canonical URL must be {expected}")
        elif relative == Path("architecture.html"):
            expected = f"{PUBLIC_ROOT}architecture.html"
            if document.canonicals != [expected]:
                failures.append(f"{path}: canonical URL must be {expected}")

        for attribute, value in document.references:
            parsed = urllib.parse.urlsplit(value)
            if parsed.scheme in {"http", "https"}:
                external_urls.add(value)
                continue
            try:
                resolved = local_target(site_dir, path, value)
            except ValueError as error:
                failures.append(f"{path}: {attribute}={value!r}: {error}")
                continue
            if resolved is None:
                continue
            target, fragment = resolved
            if not target.is_file():
                failures.append(f"{path}: {attribute}={value!r} is missing")
                continue
            if fragment and target.suffix.lower() == ".html":
                target_document = documents.get(target) or parse_document(target)
                documents[target] = target_document
                if fragment not in target_document.ids:
                    failures.append(
                        f"{path}: {attribute}={value!r} has a missing anchor"
                    )

    for css_path in sorted(site_dir.glob("*.css")):
        for value in re.findall(
            r'url\(["\']?([^"\')]+)', css_path.read_text(encoding="utf-8")
        ):
            try:
                resolved = local_target(site_dir, css_path, value)
            except ValueError as error:
                failures.append(f"{css_path}: url({value!r}): {error}")
                continue
            if resolved and not resolved[0].is_file():
                failures.append(f"{css_path}: url({value!r}) is missing")

    for path in sorted(source_site_dir.rglob("*.html")):
        if VERSIONED_RELEASE.search(path.read_text(encoding="utf-8")):
            failures.append(f"{path}: source HTML hardcodes a release version")

    metadata_path = site_dir / "release.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        for key in ("native_url", "native_checksum_url", "release_url"):
            value = metadata[key]
            parsed = urllib.parse.urlsplit(value)
            if parsed.scheme != "https" or parsed.netloc != "github.com":
                failures.append(f"{metadata_path}: {key} is not an HTTPS GitHub URL")
            external_urls.add(value)
    except (KeyError, OSError, json.JSONDecodeError) as error:
        failures.append(f"{metadata_path}: invalid generated metadata: {error}")

    sitemap_path = site_dir / "sitemap.xml"
    try:
        namespace = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        locations = {
            node.text
            for node in ET.parse(sitemap_path).findall("s:url/s:loc", namespace)
        }
        expected_locations = {
            PUBLIC_ROOT,
            f"{PUBLIC_ROOT}architecture.html",
            f"{PUBLIC_ROOT}changelog/",
        }
        if locations != expected_locations:
            failures.append(f"{sitemap_path}: URLs do not match public HTML documents")
    except (OSError, ET.ParseError) as error:
        failures.append(f"{sitemap_path}: invalid sitemap: {error}")

    robots_path = site_dir / "robots.txt"
    try:
        robots = robots_path.read_text(encoding="utf-8")
        if f"Sitemap: {PUBLIC_ROOT}sitemap.xml" not in robots:
            failures.append(f"{robots_path}: sitemap URL is missing")
    except OSError as error:
        failures.append(f"{robots_path}: cannot read robots file: {error}")

    if os.environ.get("CHECK_EXTERNAL_LINKS") == "1":
        for url in sorted(external_urls):
            failure = check_external(url)
            if failure:
                failures.append(f"external link failed: {url}: {failure}")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"ok: {len(documents)} HTML documents and {len(external_urls)} external URLs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
