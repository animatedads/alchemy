import importlib.util
import pathlib
import sys
import tempfile
import unittest
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools'))
from compare_upstream import compare, inventory

class UpstreamDiffTests(unittest.TestCase):
    def make(self, entries):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = pathlib.Path(tmp.name) / 'source.zip'
        with zipfile.ZipFile(path, 'w') as stream:
            for name, data in entries:
                stream.writestr(name, data)
        return path

    def test_changed_added_removed_unchanged(self):
        a = self.make([('same', '1'), ('changed', '1'), ('removed', '1')])
        b = self.make([('same', '1'), ('changed', '2'), ('added', '1')])
        result = compare(a,b)
        self.assertEqual(result['unchanged'], ['same'])
        self.assertEqual(result['changed'], ['changed'])
        self.assertEqual(result['added'], ['added'])
        self.assertEqual(result['removed'], ['removed'])
        self.assertEqual(result['native_qualification'], 'NOT_ASSESSED')

    def test_unsafe_path_rejected(self):
        with self.assertRaises(ValueError):
            inventory(self.make([('../bad', 'x')]))

    def test_duplicate_rejected(self):
        with self.assertRaises(ValueError):
            inventory(self.make([('A', 'x'), ('a', 'x')]))

    def test_member_limit_checked(self):
        with self.assertRaises(ValueError):
            inventory(self.make([('a', 'z'*1000)]), max_member=10)

if __name__ == '__main__':
    unittest.main()
