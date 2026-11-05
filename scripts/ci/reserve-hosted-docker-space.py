#!/usr/bin/env python3
"""Reserve scratch space using only GitHub-hosted Linux's unused Android cache."""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

CACHE = Path('/usr/local/lib/android')
MIN_FREE_BYTES = 24 * 1024 ** 3


def command(args):
    result = subprocess.run(args, check=True, text=True, capture_output=True, timeout=120)
    if result.stdout:
        print(result.stdout, end='' if result.stdout.endswith('\n') else '\n', flush=True)
    return result.stdout


def cache_identity(root):
    """Reject indirect directories and mounts before any cache mutation."""
    target = root / str(CACHE).lstrip('/')
    for path in [target, *target.parents]:
        if path == root:
            break
        if path.is_symlink():
            raise ValueError('Android cache path or ancestor is a symlink')
    if target.resolve() != target:
        raise ValueError('Android cache path is not canonical')
    if target.exists() and not target.is_dir():
        raise ValueError('Android cache path is not a directory')
    lines = (root / 'proc/self/mountinfo').read_text().splitlines()
    if not lines:
        raise ValueError('cannot validate an empty mount inventory')
    for line in lines:
        fields = line.split()
        separator = fields.index('-') if '-' in fields else -1
        if len(fields) < 10 or separator < 6 or len(fields) != separator + 4:
            raise ValueError('cannot validate the mount inventory')
        point = Path(re.sub(r'\\([0-7]{3})', lambda m: chr(int(m[1], 8)), fields[4]))
        if not point.is_absolute():
            raise ValueError('mount inventory contains a relative path')
        if point == target or point.is_relative_to(target):
            raise ValueError('Android cache contains a mount')
    if not target.exists():
        return None
    info = target.stat()
    if info.st_dev != root.stat().st_dev or os.path.ismount(target):
        raise ValueError('Android cache is a separate filesystem')
    return info.st_dev, info.st_ino, info.st_mode


def reserve(environment, *, apply=False, root=Path('/'), system=None,
            run=command, disk_usage=shutil.disk_usage):
    """Root/system/command seams are fixtures only; the CLI accepts no path options."""
    system = platform.system() if system is None else system
    if (environment.get('GITHUB_ACTIONS') != 'true'
            or environment.get('CI_RUNNER_ENVIRONMENT') != 'github-hosted'
            or environment.get('RUNNER_OS') != 'Linux' or system != 'Linux'):
        raise ValueError('disk reservation requires GitHub-hosted Linux')
    if (root / '.dockerenv').exists() or (root / 'run/.containerenv').exists():
        raise ValueError('disk reservation refuses container environments')
    root = root.resolve()
    identity = cache_identity(root)
    target = root / str(CACHE).lstrip('/')
    before = disk_usage(root).free
    run(['df', '-h', str(root)])
    if identity is not None:
        run(['du', '-sx', '--block-size=1', '--', str(target)])
    result = {'cache': str(CACHE), 'free_before_bytes': before,
              'minimum_free_bytes': MIN_FREE_BYTES, 'cache_present': identity is not None,
              'mode': 'apply' if apply else 'read-only-plan'}
    if not apply:
        print(json.dumps(result), flush=True)
        return result
    # Diagnostics must not become a window for a changed target or new mount.
    if cache_identity(root) != identity:
        raise ValueError('Android cache identity changed during preflight')
    if identity is not None:
        run(['sudo', '-n', 'rm', '-rf', '--one-file-system', '--', str(target)])
        if target.exists() or target.is_symlink():
            raise ValueError('Android cache removal did not complete')
    after = disk_usage(root).free
    run(['df', '-h', str(root)])
    result.update(free_after_bytes=after, cache_present_after=False)
    print(json.dumps(result), flush=True)
    if after < MIN_FREE_BYTES:
        raise ValueError(f'hosted Docker scratch budget is insufficient: {after} bytes '
                         f'available; require {MIN_FREE_BYTES} bytes')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='remove only the validated Android cache')
    args = parser.parse_args()
    try:
        reserve(os.environ, apply=args.apply)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Hosted disk reservation failed: {error}\n')


if __name__ == '__main__':
    main()
