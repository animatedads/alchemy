import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class ContractStaticTests(unittest.TestCase):
    def test_schema(self):
        contract = json.loads((ROOT / "contracts/time-change-v0.9.json").read_text())
        self.assertEqual(contract["schema"], "single.time.change/0.1")
        self.assertEqual(contract["deliverySemantics"], "UNPUBLISHED_PROJECTION")

    def test_no_transport_or_execution_api(self):
        src = (ROOT / "src/TimeChangePublication.cls").read_text()
        for literal in ["UNPUBLISHED_PROJECTION", "ADVISORY_ONLY", "ruleFromSnapshotId", "ruleToSnapshotId", "maxChanges"]:
            self.assertIn(literal, src)
        for forbidden in ["::method dispatch", "::method enqueue", "::method acknowledge", "::method send"]:
            self.assertNotIn(forbidden, src)

if __name__ == "__main__":
    unittest.main()
