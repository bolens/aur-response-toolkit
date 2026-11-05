"""Hosted cache reclamation cannot target a developer, mount or workspace."""

import importlib.util
import io
import shutil
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace

SPEC = importlib.util.spec_from_file_location(
    'hosted_space', Path(__file__).resolve().parents[1] / 'scripts/ci/reserve-hosted-docker-space.py')
SPACE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SPACE)


class HostedDiskGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.target = self.root / 'usr/local/lib/android'
        self.target.mkdir(parents=True)
        (self.target / 'owned-cache').write_text('disposable SDK')
        self.workspace = self.root / 'workspace'
        self.workspace.mkdir()
        (self.workspace / 'preserve').write_text('original source')
        self.mountinfo = self.root / 'proc/self/mountinfo'
        self.mountinfo.parent.mkdir(parents=True)
        self.mountinfo.write_text('1 0 0:1 / / rw - ext4 fixture rw\n')
        self.environment = {'GITHUB_ACTIONS': 'true', 'RUNNER_OS': 'Linux',
                            'CI_RUNNER_ENVIRONMENT': 'github-hosted'}
        self.calls = []

    def execute(self, args):
        self.calls.append(args)
        if args[0] == 'sudo':
            self.assertEqual(args, ['sudo', '-n', 'rm', '-rf', '--one-file-system', '--', str(self.target)])
            shutil.rmtree(self.target)
        return ''

    def reserve(self, **kwargs):
        with redirect_stdout(io.StringIO()):
            return SPACE.reserve(self.environment, root=self.root, system='Linux', run=self.execute,
                                 disk_usage=lambda _: SimpleNamespace(free=SPACE.MIN_FREE_BYTES + 1),
                                 **kwargs)

    def assert_no_mutation(self):
        self.assertTrue((self.target / 'owned-cache').exists())
        self.assertEqual((self.workspace / 'preserve').read_text(), 'original source')
        self.assertFalse(any(call[0] == 'sudo' for call in self.calls))

    def test_default_plan_is_readonly_and_apply_removes_only_owned_cache(self):
        self.assertEqual(self.reserve()['mode'], 'read-only-plan')
        self.assert_no_mutation()
        result = self.reserve(apply=True)
        self.assertFalse(self.target.exists())
        self.assertGreaterEqual(result['free_after_bytes'], SPACE.MIN_FREE_BYTES)
        self.assertEqual((self.workspace / 'preserve').read_text(), 'original source')

    def test_selfhosted_nonlinux_and_nongithub_are_denied_before_commands(self):
        for key, value in [('CI_RUNNER_ENVIRONMENT', 'self-hosted'), ('RUNNER_OS', 'macOS'),
                           ('GITHUB_ACTIONS', 'false')]:
            original = self.environment[key]
            self.environment[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.reserve(apply=True)
            self.environment[key] = original
        self.assertEqual(self.calls, [])
        self.assert_no_mutation()

    def test_container_marker_blocks_reclamation(self):
        (self.root / '.dockerenv').touch()
        with self.assertRaises(ValueError):
            self.reserve(apply=True)
        self.assertEqual(self.calls, [])
        self.assert_no_mutation()

    def test_symlink_target_or_ancestor_is_refused(self):
        actual = self.root / 'saved-cache'
        self.target.rename(actual)
        self.target.symlink_to(actual, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.reserve(apply=True)
        self.assertTrue((actual / 'owned-cache').exists())
        self.assertEqual(self.calls, [])

    def test_symlink_ancestor_is_refused(self):
        actual = self.root / 'saved-lib'
        self.target.parent.rename(actual)
        self.target.parent.symlink_to(actual, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.reserve(apply=True)
        self.assertTrue((actual / 'android/owned-cache').exists())
        self.assertEqual(self.calls, [])

    def test_unreadable_empty_or_malformed_mount_inventory_is_refused(self):
        for data in ['', 'invalid', '1 0 0:1 / relative rw - ext4 fixture rw\n']:
            self.mountinfo.write_text(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                self.reserve(apply=True)
        self.mountinfo.unlink()
        with self.assertRaises(OSError):
            self.reserve(apply=True)
        self.assertEqual(self.calls, [])
        self.assert_no_mutation()

    def test_absent_cache_still_requires_the_free_budget(self):
        shutil.rmtree(self.target)
        with redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, 'budget is insufficient'):
            SPACE.reserve(self.environment, apply=True, root=self.root, system='Linux', run=self.execute,
                          disk_usage=lambda _: SimpleNamespace(free=1))
        self.assertFalse(any(call[0] == 'sudo' for call in self.calls))
        self.assertEqual((self.workspace / 'preserve').read_text(), 'original source')

    def test_target_and_descendant_mounts_are_refused(self):
        for point in [self.target, self.target / 'sdk']:
            self.mountinfo.write_text(f'1 0 0:1 / {point} rw - ext4 fixture rw\n')
            with self.subTest(point=point), self.assertRaises(ValueError):
                self.reserve(apply=True)
        self.assert_no_mutation()

    def test_identity_change_during_diagnostics_denies_removal(self):
        original_run = self.execute
        def change(args):
            output = original_run(args)
            if args[0] == 'du':
                self.target.rename(self.root / 'saved-cache')
                self.target.mkdir()
            return output
        with redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
            SPACE.reserve(self.environment, apply=True, root=self.root, system='Linux', run=change,
                          disk_usage=lambda _: SimpleNamespace(free=SPACE.MIN_FREE_BYTES + 1))
        self.assertTrue((self.root / 'saved-cache/owned-cache').exists())
        self.assertFalse(any(call[0] == 'sudo' for call in self.calls))

    def test_insufficient_budget_fails_after_only_the_cache_is_removed(self):
        with redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, 'budget is insufficient'):
            SPACE.reserve(self.environment, apply=True, root=self.root, system='Linux', run=self.execute,
                          disk_usage=lambda _: SimpleNamespace(free=1))
        self.assertFalse(self.target.exists())
        self.assertEqual((self.workspace / 'preserve').read_text(), 'original source')

    def test_removal_failure_is_not_treated_as_reserved_space(self):
        def fail(args):
            if args[0] == 'sudo':
                raise subprocess.CalledProcessError(1, args)
            return self.execute(args)
        with redirect_stdout(io.StringIO()), self.assertRaises(subprocess.CalledProcessError):
            SPACE.reserve(self.environment, apply=True, root=self.root, system='Linux', run=fail,
                          disk_usage=lambda _: SimpleNamespace(free=SPACE.MIN_FREE_BYTES + 1))
        self.assert_no_mutation()

    def test_child_symlink_cannot_delete_workspace(self):
        (self.target / 'source-alias').symlink_to(self.workspace, target_is_directory=True)
        self.reserve(apply=True)
        self.assertEqual((self.workspace / 'preserve').read_text(), 'original source')
