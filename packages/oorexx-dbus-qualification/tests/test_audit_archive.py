"""Regression cases for conservative ZIP inspection. No original C++ exercised."""
import pathlib
import stat
import sys
import tempfile
import unittest
import zipfile
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "tools"))
from audit_archive import audit


class ArchiveAuditTests(unittest.TestCase):
    def make_archive(self, entries, compression=zipfile.ZIP_STORED):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = pathlib.Path(tmp.name) / "fixture.zip"
        with zipfile.ZipFile(path, "w", compression=compression) as stream:
            for name, data in entries:
                stream.writestr(name, data)
        return path

    def test_clean(self):
        result = audit(self.make_archive([("dbus.cls", "hello")]))
        self.assertEqual((result["status"], result["integrity"]), ("PASS", "PASS"))

    def test_traversal(self):
        self.assertIn("UNSAFE_PATH:../bad", audit(self.make_archive([("../bad", "x")]))["findings"])

    def test_backslash_traversal(self):
        self.assertIn("UNSAFE_PATH:a\\..\\b", audit(self.make_archive([("a\\..\\b", "x")]))["findings"])

    def test_absolute(self):
        self.assertEqual(audit(self.make_archive([("/etc/a", "x")]))["status"], "FAIL")

    def test_duplicate_normalized(self):
        self.assertEqual(audit(self.make_archive([("A/file", "x"), ("a/file", "y")]))["status"], "FAIL")

    def test_directory_file_collision(self):
        self.assertEqual(audit(self.make_archive([("a/", ""), ("a", "x")]))["status"], "FAIL")

    def test_windows_drive(self):
        self.assertEqual(audit(self.make_archive([("C:/file", "x")]))["status"], "FAIL")

    def test_file_count_limit_before_decompression(self):
        path = self.make_archive([("a", "a"), ("b", "b")])
        with mock.patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("decompressed")):
            result = audit(path, max_members=1)
        self.assertIn("MEMBER_COUNT_LIMIT", result["findings"])
        self.assertEqual(result["integrity"], "NOT_RUN")

    def test_expansion_limit_before_decompression(self):
        path = self.make_archive([("large", "x" * 200000)], zipfile.ZIP_DEFLATED)
        with mock.patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("decompressed")):
            result = audit(path, max_ratio=20)
        self.assertIn("EXPANSION_RATIO:large", result["findings"])
        self.assertEqual(result["integrity"], "NOT_RUN")

    def test_member_size_limit_before_decompression(self):
        path = self.make_archive([("data", "x" * 1000)])
        with mock.patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("decompressed")):
            result = audit(path, max_member=999)
        self.assertIn("MEMBER_SIZE_LIMIT:data", result["findings"])

    def test_total_size_limit_before_decompression(self):
        path = self.make_archive([("a", "x" * 10), ("b", "x" * 10)])
        with mock.patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("decompressed")):
            result = audit(path, max_total=19)
        self.assertIn("TOTAL_SIZE_LIMIT", result["findings"])

    def test_symlink_rejected(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = pathlib.Path(tmp.name) / "symlink.zip"
        info = zipfile.ZipInfo("alias")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(path, "w") as stream:
            stream.writestr(info, "target")
        self.assertIn("SPECIAL_FILE:alias", audit(path)["findings"])

    def test_corrupt_member_crc(self):
        path = self.make_archive([("data", "a")])
        raw = bytearray(path.read_bytes())
        with zipfile.ZipFile(path) as stream:
            info = stream.infolist()[0]
            offset = info.header_offset + 30 + len(info.filename.encode()) + len(info.extra)
        raw[offset] ^= 1
        path.write_bytes(raw)
        result = audit(path)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any(s.startswith("INTEGRITY_ERROR:") for s in result["findings"]))

    def test_missing_archive(self):
        self.assertEqual(audit("/does/not/exist.zip")["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
