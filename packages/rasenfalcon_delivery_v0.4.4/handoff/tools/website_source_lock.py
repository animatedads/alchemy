#!/usr/bin/env python3
"""Verify or explicitly refresh the Rasen Falcon owned website source lock.

This is development/build evidence, NOT a signature, CMS approval or release receipt.
The historical original Builder ZIP identity is immutable and is not recomputed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

PACKAGE = Path(__file__).resolve().parents[2]
WEBSITE = PACKAGE / 'website'
LOCK = PACKAGE / 'handoff' / 'public_site' / 'github_source.lock.json'
SOURCE_DIRS = frozenset(('assets', 'content', 'deploy', 'docs', 'integrations', 'server', 'tests', 'tools'))
LOCK_SCHEMA = 'rasenfalcon.github-source-lock/0.1'


def inventory(website: Path) -> dict[str, str]:
    """Enumerate the entire owned source, excluding generated site and cache."""
    if not website.is_dir() or website.is_symlink():
        raise ValueError('website root must be a real directory')
    observed = {}
    for child in website.iterdir():
        if child.name == 'site':
            continue   # Generated output is never source authority.
        if child.name not in SOURCE_DIRS or child.is_symlink() or not child.is_dir():
            raise ValueError('unexpected website source root: ' + child.name)
        for p in child.rglob('*'):
            rel = p.relative_to(website)
            if '__pycache__' in rel.parts or p.suffix == '.pyc':
                continue
            if p.is_symlink():
                raise ValueError('symlink forbidden in website source: ' + str(rel))
            if p.is_dir():
                continue
            if not p.is_file():
                raise ValueError('nonregular website source: ' + str(rel))
            key = rel.as_posix()
            observed[key] = hashlib.sha256(p.read_bytes()).hexdigest()
    if len(observed) < 20 or not any(key.startswith('content/pages/') for key in observed):
        raise ValueError('website source inventory unexpectedly incomplete')
    return dict(sorted(observed.items()))


def verify(manifest: dict, website: Path) -> dict[str, str]:
    if manifest.get('schema') != LOCK_SCHEMA or manifest.get('published_source') != 'website/':
        raise ValueError('unsupported source lock contract')
    if not manifest.get('source_archive_is_not_embedded'):
        raise ValueError('original archive source boundary not maintained')
    pin = manifest.get('source_archive_sha256')
    if not isinstance(pin, str) or len(pin) != 64 or any(c not in '0123456789abcdef' for c in pin):
        raise ValueError('original archive SHA-256 missing')
    actual = inventory(website)
    expected = manifest.get('files_sha256')
    if not isinstance(expected, dict):
        raise ValueError('source digest map missing')
    missing = sorted(set(actual) - set(expected))
    extra = sorted(set(expected) - set(actual))
    altered = sorted(k for k in set(actual) & set(expected) if actual[k] != expected[k])
    if missing or extra or altered:
        raise ValueError('source-lock drift: untracked=' + repr(missing) +
                         ' removed=' + repr(extra) + ' changed=' + repr(altered))
    return actual


def refresh(manifest: dict, website: Path) -> dict:
    # Recalculate ONLY the editable owned source SHA map. Never rewrite the
    # historical ZIP identity, live readiness or CMS/Wire publication status.
    if manifest.get('schema') != LOCK_SCHEMA or manifest.get('published_source') != 'website/':
        raise ValueError('unsupported source lock contract')
    if not manifest.get('source_archive_is_not_embedded') or not manifest.get('source_archive_sha256'):
        raise ValueError('historical archive provenance missing')
    result = dict(manifest)
    result['files_sha256'] = inventory(website)
    result['lock_scope'] = 'complete_owned_website_sources_excluding_generated_site'
    result['lock_status'] = 'DEVELOPMENT_SOURCE_SNAPSHOT_NOT_RELEASE_APPROVAL'
    verify(result, website)
    return result


def atomic_dump(lock_path: Path, manifest: dict) -> None:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    value = json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=False) + '\n'
    fd, tmp = tempfile.mkstemp(prefix='.github_source.lock.', suffix='.tmp', dir=lock_path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(value)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, lock_path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('check', 'refresh'))
    p.add_argument('--website', type=Path, default=WEBSITE)
    p.add_argument('--manifest', type=Path, default=LOCK)
    ns = p.parse_args(argv)
    try:
        current = json.loads(ns.manifest.read_text(encoding='utf-8'))
        if ns.action == 'refresh':
            updated = refresh(current, ns.website)
            atomic_dump(ns.manifest, updated)
            print(json.dumps({'ok': True, 'action': 'refresh', 'source_files': len(updated['files_sha256']),
                              'release_approval': False}, sort_keys=True))
        else:
            result = verify(current, ns.website)
            print(json.dumps({'ok': True, 'action': 'check', 'source_files': len(result),
                              'release_approval': False}, sort_keys=True))
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc), 'release_approval': False}), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
