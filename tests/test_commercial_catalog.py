"""Static commercial proposal invariants, not production tests."""
import json
from pathlib import Path
import unittest
C = Path(__file__).resolve().parents[1] / "docs/commercial/catalog.v0.2.json"
class CatalogueTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.data = json.loads(C.read_text(encoding="utf-8"))
    def test_not_for_sale(self):
        self.assertEqual(self.data["schema"], "alchemy.commercial.portfolio/0.2")
        self.assertEqual(self.data["status"], "DESIGN_NOT_FOR_SALE")
    def test_counts_and_uniqueness(self):
        gs = self.data["groups"]
        self.assertEqual(len(gs), 18)
        skus = [p["sku"] for g in gs for p in g["plans"]]
        self.assertEqual(len(skus), 46)
        self.assertEqual(len(skus), len(set(skus)))
        self.assertEqual(len({g["code"] for g in gs}), 18)
    def test_no_accidental_qualified_skus(self):
        for g in self.data["groups"]:
            self.assertEqual(g["publication_status"], "UNQUALIFIED_PROPOSAL")
            for p in g["plans"]:
                self.assertGreater(p["list_usd_month"],0)
                self.assertGreater(p["included_commercial_wlu_month"],0)
                self.assertEqual(p["allowance_status"], "PROVISIONAL_NOT_ENFORCED")
    def test_sensitive_verticals_design_partner_only(self):
        for g in self.data["groups"]:
            if g["code"] in ("FIN", "INS"):
                self.assertEqual(g["plans"],[])
                self.assertEqual(g["launch_wave"],"Design partner")
    def test_notnotes_prices(self):
        n = next(g for g in self.data["groups"] if g["code"]=="NNFO")
        self.assertEqual([p["list_usd_month"] for p in n["plans"]],[149,299,499])
if __name__=="__main__": unittest.main()
