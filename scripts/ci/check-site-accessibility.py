#!/usr/bin/env python3
"""Check static accessibility contracts without executing third-party content."""

from __future__ import annotations

import os
import sys
from html.parser import HTMLParser
from pathlib import Path


class AccessibilityDocument(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.failures: list[str] = []
        self.html_lang = ""
        self.has_title = False
        self.has_viewport = False
        self.main_count = 0
        self.heading_levels: list[int] = []
        self.label_targets: set[str] = set()
        self.unlabelled_inputs: list[str] = []
        self._stack: list[tuple[str, dict[str, str], list[str]]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {name: value or "" for name, value in attrs}
        if tag == "html":
            self.html_lang = values.get("lang", "")
        elif tag == "meta" and values.get("name") == "viewport":
            self.has_viewport = True
        elif tag == "main":
            self.main_count += 1
        elif tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            self.heading_levels.append(int(tag[1]))
        elif tag == "img" and "alt" not in values and values.get("role") != "presentation":
            self.failures.append("image has no alt text")
        elif tag == "iframe" and not values.get("title"):
            self.failures.append("iframe has no title")
        elif tag == "nav" and not (values.get("aria-label") or values.get("aria-labelledby")):
            self.failures.append("navigation landmark has no accessible name")
        elif tag == "label" and values.get("for"):
            self.label_targets.add(values["for"])
        elif tag == "input" and values.get("type", "text") != "hidden":
            if not (values.get("aria-label") or values.get("aria-labelledby")):
                self.unlabelled_inputs.append(values.get("id", ""))
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}:
            self._stack.append((tag, values, []))

    def handle_data(self, data: str) -> None:
        for _, _, text in self._stack:
            text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if not self._stack:
            return
        index = next((i for i in range(len(self._stack) - 1, -1, -1) if self._stack[i][0] == tag), None)
        if index is None:
            return
        opened_tag, values, text_parts = self._stack[index]
        del self._stack[index:]
        text = " ".join("".join(text_parts).split())
        name = values.get("aria-label") or text
        if opened_tag == "title":
            self.has_title = bool(text)
        elif opened_tag in {"a", "button", "summary"} and not name:
            self.failures.append(f"{opened_tag} has no accessible name")

    def finish(self) -> list[str]:
        if not self.html_lang:
            self.failures.append("html has no language")
        if not self.has_title:
            self.failures.append("document has no title")
        if not self.has_viewport:
            self.failures.append("document has no viewport metadata")
        if self.main_count != 1:
            self.failures.append(f"document has {self.main_count} main landmarks")
        if self.heading_levels.count(1) != 1:
            self.failures.append(f"document has {self.heading_levels.count(1)} h1 elements")
        for input_id in self.unlabelled_inputs:
            if not input_id or input_id not in self.label_targets:
                self.failures.append("input has no accessible name")
        for previous, current in zip(self.heading_levels, self.heading_levels[1:]):
            if current > previous + 1:
                self.failures.append(f"heading level jumps from h{previous} to h{current}")
        return self.failures


def main() -> int:
    site_dir = Path(os.environ.get("SITE_DIR", "site"))
    failures: list[str] = []
    pages = sorted(site_dir.glob("*.html"))
    for asset in ("theme.js", "theme-modes.css", "favicon.ico", "favicon.png", "apple-touch-icon.png", "icon-192.png", "icon-512.png", "og.png", "site.webmanifest"):
        if not (site_dir / asset).is_file():
            failures.append(f"{site_dir / asset}: missing discovery asset")
    for path in pages:
        document = AccessibilityDocument()
        document.feed(path.read_text(encoding="utf-8"))
        failures.extend(f"{path}: {failure}" for failure in document.finish())

    css = (site_dir / "styles.css").read_text(encoding="utf-8")
    script = (site_dir / "app.js").read_text(encoding="utf-8")
    home = (site_dir / "index.html").read_text(encoding="utf-8")
    for contract in ('og:site_name', 'twitter:image:alt', 'rel="apple-touch-icon"', 'rel="manifest"'):
        if contract not in home:
            failures.append(f"{site_dir / 'index.html'}: missing discovery contract {contract}")
    if "reveal-ready" in css:
        failures.append(f"{site_dir / 'styles.css'}: primary content must not use reveal-ready concealment")
    if "IntersectionObserver" in script and 'classList.add("reveal")' in script:
        failures.append(f"{site_dir / 'app.js'}: primary content must not use observer-driven reveal classes")
    if "@media (prefers-reduced-motion: reduce)" not in css:
        failures.append(f"{site_dir / 'styles.css'}: no reduced-motion fallback")
    if ":focus-visible" not in css:
        failures.append(f"{site_dir / 'styles.css'}: no visible keyboard focus rule")
    theme_source = (site_dir / "theme.js").read_text(encoding="utf-8")
    for behavior in ("prefers-color-scheme: light", "prefers-color-scheme: dark", "new Date().getHours()", "return \"dark\"", "localStorage.setItem"):
        if behavior not in theme_source:
            failures.append(f"theme.js: missing {behavior} adaptive-theme behavior")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"ok: accessibility contracts for {len(pages)} HTML documents")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
