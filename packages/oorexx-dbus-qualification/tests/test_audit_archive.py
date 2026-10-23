import io
import pathlib
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "tools"))
from audit_archive import audit

class ArchiveAuditTests(unittest.TestCase):
    def make_archive(self, entries):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = pathlib.Path(tmp.name) / "fixture.zip"
        with zipfile.ZipFile(path, "w") as z:
            for name, data in entries:
                z.writestr(name, data)
        return path

    def test_clean(self):
        self.assertEqual(audit(self.make_archive([("dbus.cls", "hello")]))["status"], "PASS")

    def test_traversal(self):
        self.assertIn("UNSAFE_PATH:../bad", audit(self.make_archive([("../bad", "x")]))["findings"])

    def test_duplicate_normalized(self):
        result = audit(self.make_archive([("A/file", "x"), ("a/file", "y")]))
        self.assertEqual(result["status"], "FAIL")

    def test_expansion_limit(self):
        result = audit(self.make_archive([("long", "x" * 100)]), max_ratio=1)
        self.assertEqual(result["status"], "FAIL")

if __name__ == "__main__":
    unittest.main()
