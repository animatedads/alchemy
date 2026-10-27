"""Codex-proposed bounded document reading through read-only adapters."""
import contextlib
import io
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import ComputerActions as actions
import ComputerDocuments as documents


class DocumentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def read(self, utterance):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            rc = documents.execute(utterance, actions.ComputerError)
        return rc, buffer.getvalue()

    def test_direct_read_text_and_source(self):
        for ext in ('.md', '.cls', '.rex', '.py', '.sh'):
            with self.subTest(ext=ext):
                file = self.dir / ('read' + ext)
                file.write_text('chapter one\n', encoding='utf-8')
                rc, output = self.read(f'read document "{file}"')
                self.assertEqual(rc, 0)
                self.assertIn('chapter one', output)

    def test_zip_members_no_extraction_or_ambiguous_selection(self):
        archive = self.dir / 'package.zip'
        with zipfile.ZipFile(archive, 'w') as file:
            file.writestr('README.md', '# First\n')
            file.writestr('docs/README.md', '# Second\n')
            file.writestr('src/Crypto.cls', '::class Crypto\n')
        rc, listing = self.read(f'list documents in {archive}')
        self.assertEqual(rc, 0)
        self.assertIn('src/Crypto.cls', listing)
        rc, output = self.read(f'read document src/Crypto.cls in {archive}')
        self.assertEqual(rc, 0)
        self.assertIn('::class Crypto', output)
        self.assertIn('extracted=false', output)
        self.assertEqual([p.name for p in self.dir.iterdir()], ['package.zip'])

    def test_duplicate_member_refused(self):
        archive = self.dir / 'duplicate.zip'
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(archive, 'w') as file:
                file.writestr('README.md', 'one')
                file.writestr('README.md', 'two')
        with self.assertRaises(actions.ComputerError) as ctx:
            self.read(f'read document README.md in {archive}')
        self.assertEqual(ctx.exception.status, 4)

    def test_symlink_and_oversized_refused(self):
        text = self.dir / 'big.txt'
        text.write_bytes(b'x' * (documents.MAX_DOCUMENT_BYTES + 1))
        with self.assertRaises(actions.ComputerError) as ctx:
            self.read(f'read document {text}')
        self.assertEqual(ctx.exception.status, 4)
        link = self.dir / 'link.txt'
        link.symlink_to(text)
        with self.assertRaises(actions.ComputerError) as ctx:
            self.read(f'read document {link}')
        self.assertEqual(ctx.exception.status, 4)

    def test_zip_traversal_member_refused(self):
        archive = self.dir / 'bad.zip'
        with zipfile.ZipFile(archive, 'w') as file:
            file.writestr('../outside.txt', 'wrong')
        with self.assertRaises(actions.ComputerError) as ctx:
            self.read(f'read document ../outside.txt in {archive}')
        self.assertEqual(ctx.exception.status, 4)


if __name__ == '__main__':
    unittest.main()
