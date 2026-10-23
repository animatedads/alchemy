"""No claims of upstream coverage unless complete sources are present."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "tools" / "corpus_inventory.py"
spec = importlib.util.spec_from_file_location("corpus_inventory", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CorpusInventoryTests(unittest.TestCase):
    def test_missing_file(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            manifest = p / "files.txt"
            manifest.write_text("samples/example.rc\n")
            result = module.inventory(p, manifest)
            self.assertEqual(result[0]["status"], "missing")

    def test_missing_quoted_include(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            folder = p / "samples"
            folder.mkdir()
            (folder / "example.rc").write_text(
                '#include "resource.h"\nIDD_TEST DIALOGEX 0,0,20,20\n'
            )
            manifest = p / "files.txt"
            manifest.write_text("samples/example.rc\n")
            result = module.inventory(p, manifest)
            self.assertEqual(result[0]["status"], "incomplete_includes")
            self.assertEqual(result[0]["missing_local_includes"], ["resource.h"])

    def test_complete_source(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            folder = p / "samples"
            folder.mkdir()
            (folder / "resource.h").write_text("#define IDD_TEST 100\n")
            (folder / "example.rc").write_text(
                '#include "resource.h"\nIDD_TEST DIALOGEX 0,0,20,20\n'
            )
            manifest = p / "files.txt"
            manifest.write_text("samples/example.rc\n")
            result = module.inventory(p, manifest)
            self.assertEqual(result[0]["status"], "present")
            self.assertEqual(result[0]["resource_kind_counts_heuristic"]["DIALOGEX"], 1)
            self.assertEqual(len(result[0]["sha256"]), 64)

if __name__ == "__main__":
    unittest.main()
