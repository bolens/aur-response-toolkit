#!/usr/bin/env python3
"""Validate canonical GitHub PR metadata as data, without publisher credentials."""

import json
import os
import re
import urllib.request

PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .+"
)


def main():
    if (
        os.environ.get("CI_FORGE_TYPE") != "github"
        or os.environ.get("CI_REPO") != "bolens/aur-response-toolkit"
    ):
        return
    if os.environ.get("CI_PIPELINE_EVENT") not in {
        "pull_request",
        "pull_request_metadata",
    }:
        return
    number = os.environ["CI_COMMIT_PULL_REQUEST"]
    if not re.fullmatch(r"[0-9]+", number):
        raise ValueError("invalid PR number")
    base = f"https://api.github.com/repos/bolens/aur-response-toolkit/pulls/{number}"
    with urllib.request.urlopen(base, timeout=30) as response:
        pr = json.load(response)
    if not PATTERN.match(pr["title"]):
        raise ValueError("PR title must follow Conventional Commits")
    for page in range(1, 102):
        with urllib.request.urlopen(
            f"{base}/commits?per_page=100&page={page}", timeout=30
        ) as response:
            commits = json.load(response)
        for commit in commits:
            subject = commit["commit"]["message"].splitlines()[0]
            if not subject.startswith(
                ("Merge ", "Revert ", "fixup! ", "squash! ", "Amend! ")
            ) and not PATTERN.match(subject):
                raise ValueError("PR contains a non-conventional commit subject")
        if len(commits) < 100:
            return
    raise ValueError("PR exceeds bounded commit pagination")


if __name__ == "__main__":
    main()
