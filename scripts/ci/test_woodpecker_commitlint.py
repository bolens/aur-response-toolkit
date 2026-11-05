"""PR policy uses trusted webhook fields and Git, with no REST or publisher secret."""

import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "commitlint", Path(__file__).with_name("woodpecker-commitlint.py")
)
commitlint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(commitlint)


class CommitPolicyTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.env = {
            "CI_FORGE_TYPE": "github",
            "CI_REPO": "bolens/aur-response-toolkit",
            "CI_PIPELINE_EVENT": "pull_request",
            "CI_COMMIT_MESSAGE": "ci: migrate validation",
            "CI_COMMIT_TARGET_BRANCH": "main",
            "CI_COMMIT_SHA": self.sha,
        }

    def test_title_and_all_subjects_keep_existing_conventions(self):
        commitlint.validate(
            "feat(cli)!: preserve contract",
            ["fix(core): validate inputs", "Merge main", "fixup! cleanup"],
        )
        for title, subjects in [
            ("unconventional title", []),
            ("ci: valid", ["bad subject"]),
            ("ci: valid", [""]),
        ]:
            with (
                self.subTest(title=title, subjects=subjects),
                self.assertRaises(ValueError),
            ):
                commitlint.validate(title, subjects)

    def test_actual_webhook_title_and_full_commit_graph_need_no_rest(self):
        answers = ["main", "false", self.sha, "", "b" * 40, "ci: first\nfix: second"]
        with (
            patch.dict(os.environ, self.env, clear=True),
            patch.object(commitlint, "git", side_effect=answers) as git,
        ):
            commitlint.main()
        self.assertEqual(
            git.call_args_list[-1].args, ("log", "--format=%s", "b" * 40 + "..HEAD")
        )
        self.assertEqual(
            git.call_args_list[3].args,
            (
                "fetch",
                "--no-tags",
                "https://github.com/bolens/aur-response-toolkit.git",
                "refs/heads/main",
            ),
        )

    def test_missing_title_or_shallow_graph_cannot_skip_checks(self):
        with (
            patch.dict(os.environ, dict(self.env, CI_COMMIT_MESSAGE=""), clear=True),
            patch.object(commitlint, "git") as git,
            self.assertRaises(ValueError),
        ):
            commitlint.main()
        git.assert_not_called()
        with (
            patch.dict(os.environ, self.env, clear=True),
            patch.object(commitlint, "git", side_effect=["main", "true"]),
            self.assertRaises(ValueError),
        ):
            commitlint.main()


if __name__ == "__main__":
    unittest.main()
