"""Prevent recurrence of the website/current-source digest drift.

Fixtures are scratch copies, not official review or live service approvals.
"""
from __future__ import annotations

import importlib.util
import json
import pathlib
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MOD = ROOT / 'handoff/tools/website_source_lock.py'
SPEC = importlib.util.spec_from_file_location('rf_website_source_lock', MOD)
locktool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(locktool)


class SourceLockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = json.loads((ROOT/'handoff/public_site/github_source.lock.json').read_text())

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rasen-source-lock-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.website = self.root/'website'
        shutil.copytree(ROOT/'website', self.website, ignore=shutil.ignore_patterns('__pycache__', '*.pyc','site'))
        self.manifest = json.loads(json.dumps(self.original))

    def test_live_source_snapshot_is_in_sync(self):
        actual = locktool.verify(self.original, ROOT/'website')
        self.assertEqual(28,len(actual))
        self.assertEqual(set(self.original['files_sha256']),set(actual))

    def test_tracked_content_modification_fails(self):
        target = self.website/'content/pages/home.json'
        target.write_bytes(target.read_bytes()+b'\n')
        with self.assertRaisesRegex(ValueError,'changed=.*content/pages/home.json'):
            locktool.verify(self.manifest,self.website)

    def test_untracked_source_file_fails(self):
        (self.website/'docs/unsourced.md').write_text('not pinned')
        with self.assertRaisesRegex(ValueError,'untracked=.*docs/unsourced.md'):
            locktool.verify(self.manifest,self.website)

    def test_deleted_source_file_fails(self):
        (self.website/'docs/README.md').unlink()
        with self.assertRaisesRegex(ValueError,'removed=.*docs/README.md'):
            locktool.verify(self.manifest,self.website)

    def test_source_symlink_fails(self):
        (self.website/'docs/link.md').symlink_to(self.website/'content/site.json')
        with self.assertRaisesRegex(ValueError,'symlink forbidden'):
            locktool.verify(self.manifest,self.website)

    def test_explicit_refresh_preserves_historical_identity(self):
        before = dict(self.manifest)
        target = self.website/'docs/README.md'
        target.write_bytes(target.read_bytes()+b'\n')
        modified = locktool.refresh(self.manifest,self.website)
        self.assertNotEqual(modified['files_sha256']['docs/README.md'],before['files_sha256']['docs/README.md'])
        for key in ('source_archive_sha256','source_archive_original','source_archive_is_not_embedded','cms_brand_wire_live','https_runtime_live'):
            self.assertEqual(modified[key],before[key])
        self.assertEqual('DEVELOPMENT_SOURCE_SNAPSHOT_NOT_RELEASE_APPROVAL',modified['lock_status'])
        self.assertEqual(locktool.verify(modified,self.website),modified['files_sha256'])

    def test_generated_site_is_excluded(self):
        p = self.website/'site/generated.html'
        p.parent.mkdir(parents=True)
        p.write_text('not authoritative')
        self.assertEqual(locktool.verify(self.manifest,self.website),self.original['files_sha256'])

    def test_malformed_manifest_and_archive_pin_fail(self):
        broken = dict(self.manifest,source_archive_sha256='not-a-digest')
        with self.assertRaisesRegex(ValueError,'archive SHA-256 missing'):
            locktool.verify(broken,self.website)


if __name__ == '__main__':
    unittest.main()
