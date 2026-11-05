#!/usr/bin/env python3
"""Validate webhook PR titles and the full cloned Git graph without API credentials."""

import os
import re
import subprocess

PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .+"
)
EXEMPT = ("Merge ", "Revert ", "fixup! ", "squash! ", "Amend! ")


def git(*args):
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith(("GH_", "GITHUB_", "GIT_TRACE", "GIT_CURL", "CI_NETRC_"))
        and key not in {"PUBLISHER_LEASE", "WOODPECKER_PUBLISH_LEASE"}
    }
    environment.update(
        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_TERMINAL_PROMPT="0"
    )
    return subprocess.check_output(
        ["git", "-c", "credential.helper=", *args],
        text=True,
        env=environment,
        timeout=120,
    ).strip()


def validate(title, subjects):
    if not PATTERN.match(title):
        raise ValueError("PR title must follow Conventional Commits")
    for subject in subjects:
        if not subject.startswith(EXEMPT) and not PATTERN.match(subject):
            raise ValueError("PR contains a non-conventional commit subject")


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
    # Both Woodpecker 3.18.0 and 3.20.1's GitHub parsePullHook map the PR title
    # to Commit.Message, exported as CI_COMMIT_MESSAGE. There is no PR_TITLE builtin.
    title = os.environ.get("CI_COMMIT_MESSAGE", "")
    validate(title, [])
    target = os.environ.get("CI_COMMIT_TARGET_BRANCH", "")
    if not target:
        raise ValueError("missing webhook target branch")
    git("check-ref-format", "--branch", target)
    if git("rev-parse", "--is-shallow-repository") != "false":
        raise ValueError("commit policy requires the configured full-history clone")
    sha = os.environ.get("CI_COMMIT_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or git("rev-parse", "HEAD") != sha:
        raise ValueError("checkout differs from the webhook source")
    git(
        "fetch",
        "--no-tags",
        "https://github.com/bolens/aur-response-toolkit.git",
        "refs/heads/" + target,
    )
    base = git("merge-base", "HEAD", "FETCH_HEAD")
    subjects = git("log", "--format=%s", base + "..HEAD").splitlines()
    validate(title, subjects)
    print(f"Conventional PR title and {len(subjects)} cloned commit subjects verified.")


if __name__ == "__main__":
    main()
