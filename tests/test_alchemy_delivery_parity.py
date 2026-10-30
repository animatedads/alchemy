#!/usr/bin/env python3
"""Offline regression for exact archive->source publication checks."""
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile

MODULE = Path(__file__).resolve().parents[1] / 'tools' / 'alchemy_delivery_parity.py'
spec = importlib.util.spec_from_file_location('parity', MODULE)
parity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parity)


class TestDeliveryParity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.target = self.root / 'package'
        self.target.mkdir()
        self.archive = self.root / 'delivery.zip'

    def zip(self, values):
        with zipfile.ZipFile(self.archive, 'w') as z:
            for name, data in values.items():
                z.writestr(name, data)

    def test_full_binary_parity(self):
        self.zip({'release/src/X.cls': b'a\r\nb\x00c', 'release/fixtures/Etc/UTC': b'TZif\x00\xff'})
        (self.target / 'src').mkdir()
        (self.target / 'fixtures' / 'Etc').mkdir(parents=True)
        (self.target / 'src' / 'X.cls').write_bytes(b'a\r\nb\x00c')
        (self.target / 'fixtures' / 'Etc' / 'UTC').write_bytes(b'TZif\x00\xff')
        r = parity.compare(self.archive, self.target)
        self.assertEqual(r['verdict'], 'SOURCE_PARITY')
        self.assertEqual(r['counts']['MATCH'], 2)
        self.assertEqual(r['qualification'], 'NOT_ASSESSED')
        self.assertEqual(r['acceptance'], 'NOT_ASSESSED')

    def test_missing_and_different_never_pass(self):
        self.zip({'release/a.txt': b'good', 'release/b.txt': b'also good'})
        (self.target / 'a.txt').write_bytes(b'bad')
        r = parity.compare(self.archive, self.target)
        self.assertEqual(r['verdict'], 'SOURCE_GAP')
        self.assertEqual(r['counts']['DIFFERENT'], 1)
        self.assertEqual(r['counts']['MISSING'], 1)

    def test_vendor_and_cache_excluded_not_adopted(self):
        self.zip({'r/src/main.rex': b'hi', 'r/vendor/third.cls': b'upstream', 'r/tests/__pycache__/a.pyc': b'cache', 'r/deps/z.txt': b'copy'})
        (self.target / 'src').mkdir()
        (self.target / 'src' / 'main.rex').write_bytes(b'hi')
        r = parity.compare(self.archive, self.target)
        self.assertEqual(r['verdict'], 'SOURCE_PARITY')
        self.assertEqual(r['counts']['excluded_dependency_or_cache'], 3)

    def test_reject_path_traversal(self):
        self.zip({'../../etc/passwd': b'bad'})
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target)

    def test_reject_double_separator(self):
        self.zip({'r//src/a': b'bad'})
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target)

    def test_reject_backslash(self):
        self.zip({'r\\src\\main.cls': b'bad'})
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target)

    def test_reject_duplicate_casefold(self):
        self.zip({'r/SRC/A.cls': b'a', 'r/src/a.cls': b'b'})
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target)

    def test_reject_symlink_archive(self):
        with zipfile.ZipFile(self.archive, 'w') as z:
            info = zipfile.ZipInfo('r/src/link')
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            z.writestr(info, b'/etc/passwd')
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target)

    def test_reject_symlink_destination(self):
        outside = self.root / 'outside.txt'
        outside.write_bytes(b'good')
        (self.target / 'file').symlink_to(outside)
        self.zip({'r/file': b'good'})
        r = parity.compare(self.archive, self.target)
        self.assertEqual(r['members'][0]['status'], 'UNSAFE_DESTINATION')

    def test_reject_parent_symlink_escape(self):
        outside = self.root / 'out'
        outside.mkdir()
        (outside / 'x').write_bytes(b'ok')
        (self.target / 'src').symlink_to(outside, target_is_directory=True)
        self.zip({'r/src/x': b'ok'})
        r = parity.compare(self.archive, self.target)
        self.assertEqual(r['members'][0]['status'], 'UNSAFE_DESTINATION')

    def test_explicit_prefix_and_flat_archive(self):
        self.zip({'src/main.rex': b'hello'})
        (self.target / 'src').mkdir()
        (self.target / 'src' / 'main.rex').write_bytes(b'hello')
        self.assertEqual(parity.compare(self.archive, self.target, 'none')['verdict'], 'SOURCE_PARITY')
        self.assertEqual(parity.compare(self.archive, self.target, 'auto')['verdict'], 'SOURCE_PARITY')
        with self.assertRaises(parity.UnsafeArchive):
            parity.compare(self.archive, self.target, 'wrong')

    def test_cli_exit_and_json(self):
        self.zip({'r/a': b'a'})
        cmd = [sys.executable, str(MODULE), '--archive', str(self.archive), '--destination', str(self.target), '--json']
        p = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(p.returncode, 1)
        self.assertIn('SOURCE_GAP', p.stdout)
        (self.target / 'a').write_bytes(b'a')
        p = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0)
        self.assertIn('SOURCE_PARITY', p.stdout)


if __name__ == '__main__':
    unittest.main()
