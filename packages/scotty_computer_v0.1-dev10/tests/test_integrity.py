"""Scotty Computer: bounded read-only integrity contracts and negative cases."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import ComputerActions as act
import ComputerIntegrity as ci


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        env = os.environ.copy()
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(env)))
        os.environ['XDG_CONFIG_HOME'] = str(self.root / 'config')
        os.environ['HOME'] = str(self.root)
        self.folder = self.root / 'Downloads'
        self.folder.mkdir()
        self.a = self.folder / 'a example.txt'
        self.b = self.folder / 'b.txt'
        self.a.write_bytes(b'Hello Scotty\n')
        self.b.write_bytes(self.a.read_bytes())
        self.digest = hashlib.sha256(self.a.read_bytes()).hexdigest()
        act.add_root(f'add {self.folder} to my find file locations', False)

    def run_cmd(self, command, mode=True):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = act.execute('FILE_INTEGRITY', ('--json ' if mode else '') + command)
        output = buf.getvalue()
        return rc, json.loads(output) if mode else output

    def test_sha256_sha512_sha1_and_aliases(self):
        for command, algo in [('sha256', 'sha256'), ('sha512', 'sha512'), ('sha1', 'sha1'),
                              ('get sha of', 'sha256'), ('get the sha256 of', 'sha256'),
                              ('calculate sha256', 'sha256'), ('hash', 'sha256')]:
            with self.subTest(command=command):
                rc, doc = self.run_cmd(f'{command} "{self.a}"')
                self.assertEqual(rc, 0, doc)
                self.assertEqual(doc['digest'], hashlib.new(algo, self.a.read_bytes()).hexdigest())
                self.assertEqual(doc['algorithm'], algo)
                self.assertEqual(doc['bytes'], self.a.stat().st_size)

    def test_compare_identical_digest_and_bytes(self):
        for op in ['sha256', 'files', 'hashes']:
            rc, doc = self.run_cmd(f'compare {op} "{self.a}" with "{self.b}"')
            self.assertEqual(rc, 0, doc)
            self.assertTrue(doc['identical'])
            self.b.write_text('Changed\n')
            rc, doc = self.run_cmd(f'compare {op} "{self.a}" with "{self.b}"')
            self.assertEqual(rc, 1, doc)
            self.assertEqual(doc['status'], 'MISMATCH')
            self.b.write_bytes(self.a.read_bytes())

    def test_verify_digest_mismatch_nonzero(self):
        rc, doc = self.run_cmd(f'verify sha256 {self.digest} "{self.a}"')
        self.assertEqual((rc, doc['status']), (0, 'MATCH'))
        rc, doc = self.run_cmd(f'verify sha256 {"0"*64} "{self.a}"')
        self.assertEqual((rc, doc['status']), (1, 'MISMATCH'))
        self.assertEqual(doc['actual'], self.digest)

    def test_manifest_missing_mismatch_and_clean(self):
        manifest = self.folder / 'SHA256SUMS'
        manifest.write_text(self.digest + '  a example.txt\n' + self.digest + ' *b.txt\n')
        rc, doc = self.run_cmd(f'verify manifest "{manifest}"')
        self.assertEqual((rc, doc['count'], doc['failed']), (0, 2, 0))
        self.b.write_text('tampered\n')
        rc, doc = self.run_cmd(f'verify manifest "{manifest}"')
        self.assertEqual((rc, doc['failed']), (1, 1))
        self.b.unlink()
        rc, doc = self.run_cmd(f'verify manifest "{manifest}"')
        self.assertEqual((rc, doc['failed']), (1, 1))

    def test_manifest_rejects_traversal_and_symlinks(self):
        manifest = self.folder / 'SHA256SUMS'
        manifest.write_text(self.digest + '  ../outside\n')
        rc, doc = self.run_cmd(f'verify manifest "{manifest}"')
        self.assertEqual(rc, 4)
        self.assertEqual(doc['status'], 'ERROR')
        manifest.write_text(self.digest + '  link.txt\n')
        (self.folder/'link.txt').symlink_to(self.a)
        rc, doc = self.run_cmd(f'verify manifest "{manifest}"')
        self.assertEqual(rc, 4)

    def test_symlink_explicit_rejected_and_missing_file(self):
        (self.folder/'link').symlink_to(self.a)
        rc, doc = self.run_cmd(f'sha256 "{self.folder / "link"}"')
        self.assertEqual(rc, 4)
        rc, doc = self.run_cmd('sha256 no_such_file')
        self.assertEqual(rc, 1)

    def test_ambiguous_basename_is_blocked(self):
        other = self.folder / 'nested'
        other.mkdir()
        (other/self.a.name).write_bytes(self.a.read_bytes())
        rc, doc = self.run_cmd('sha256 "a example.txt"')
        self.assertEqual(rc, 3)
        self.assertIn('Ambiguous', doc['error'])
        rc, doc = self.run_cmd(f'sha256 "{self.a}"')
        self.assertEqual(rc, 0)

    def test_find_sha256_in_registered_root(self):
        rc, doc = self.run_cmd(f'find sha256 {self.digest}')
        self.assertEqual(rc, 0)
        self.assertIn(str(self.a), doc['matches'])
        rc, doc = self.run_cmd(f'find sha256 {"f"*64}')
        self.assertEqual((rc, doc['status']), (1, 'NOT_FOUND'))

    def test_inspect_file(self):
        rc, doc = self.run_cmd(f'inspect "{self.a}"')
        self.assertEqual(rc, 0)
        self.assertEqual(doc['sha256'], self.digest)
        self.assertIn('modified_ns', doc)

    def test_zip_list_test_and_bad_archives(self):
        zpath = self.folder/'test.zip'
        with zipfile.ZipFile(zpath, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('nested/sample.cls', '::class Example\n')
        for operation in ('list', 'test'):
            rc, doc = self.run_cmd(f'{operation} zip "{zpath}"')
            self.assertEqual(rc, 0, doc)
            self.assertEqual(doc['count'], 1)
            self.assertEqual(doc['crc_verified'], operation == 'test')
        with zipfile.ZipFile(zpath, 'w') as z:
            z.writestr('../unsafe', 'abc')
        rc, doc = self.run_cmd(f'test zip "{zpath}"')
        self.assertEqual(rc, 4)
        zpath.write_bytes(b'not a zip')
        rc, doc = self.run_cmd(f'test zip "{zpath}"')
        self.assertEqual(rc, 1)

    def test_bad_syntax_and_bounded_scan(self):
        rc, doc = self.run_cmd('verify sha256 BAD /tmp/a')
        self.assertEqual(rc, 2)
        old = ci.MAX_HASH_SCAN_BYTES
        ci.MAX_HASH_SCAN_BYTES = 1
        try:
            rc, doc = self.run_cmd(f'find sha256 {"f"*64}')
        finally:
            ci.MAX_HASH_SCAN_BYTES = old
        self.assertEqual(rc, 3)
        self.assertIn('budget', doc['error'])

    def test_text_rendering(self):
        rc, txt = self.run_cmd(f'sha256 "{self.a}"', mode=False)
        self.assertEqual(rc, 0)
        self.assertIn('ALGORITHM="SHA256"', txt.upper())
        self.assertIn(self.digest, txt)

if __name__ == '__main__':
    unittest.main()
