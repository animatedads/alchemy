#!/usr/bin/env python3
"""Structural and authority-boundary tests; NOT a Gopher/runtime integration test."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACK = ROOT / "packs" / "cloud-economics"
SHA = "8354043fc133ef9b6fdb593ec8d000e278e0748228224464b9ebb7feb485e735"

class SphereContract(unittest.TestCase):
    def test_all_json_valid(self):
        for path in ROOT.rglob("*.json"):
            with self.subTest(path=path):
                data = json.loads(path.read_text(encoding="utf-8"))
                self.assertIsInstance(data, dict)

    def test_profile_and_sphere(self):
        p = json.loads((ROOT/"profiles/cloud-economics.json").read_text())
        s = json.loads((PACK/"00-sphere.json").read_text())
        self.assertEqual(p["id"], s["id"])
        self.assertEqual(s["access_policy"], "cloud-economics-access")
        self.assertIn("packs/cloud-economics", p["packs"])
        self.assertEqual(s["kind"], "sphere")
        self.assertEqual(json.loads((PACK/"01-access-policy.json").read_text())["id"], s["access_policy"])

    def test_index_and_articles(self):
        s=json.loads((PACK/"00-sphere.json").read_text())
        articles={}
        for f in (PACK/"articles").glob("*.json"):
            a=json.loads(f.read_text())
            self.assertEqual(a["kind"],"article")
            self.assertEqual(a["sphere"],s["id"])
            self.assertNotIn(a["id"],articles)
            self.assertTrue(a.get("invariants"))
            for source in a["provenance"]:
                self.assertEqual(source["sha256"], SHA)
            articles[a["id"]]=a
        self.assertGreaterEqual(len(articles),12)
        self.assertTrue(set(s["start_here"]).issubset(articles))
        self.assertEqual(articles["cloud-economics.realized-savings"]["implementation_status"],"PROPOSED")
        self.assertEqual(articles["cloud-economics.migration-status"]["implementation_status"],"IMPLEMENTED")
        self.assertIn("PAPER_ONLY", articles["cloud-economics.start"]["summary"])

    def test_provenance_and_financial_boundaries(self):
        e=json.loads((ROOT/"evidence/source-baseline.json").read_text())
        self.assertEqual(e["source"]["sha256"], SHA)
        self.assertEqual(e["source"]["mode"],"PAPER_ONLY")
        self.assertFalse(e["declared_status"]["real_purchasing"])
        self.assertFalse(e["declared_status"]["real_migration"])
        self.assertFalse(e["declared_status"]["status_observer_live_delivery_qualified"])
        c=json.loads((PACK/"corpora/cloud-economics.continuity.json").read_text())
        self.assertEqual(c["sphere"],"cloud-economics")
        self.assertGreaterEqual(len(c["records"]),12)
        self.assertTrue(any(r.get("topic")=="cost-measurement" for r in c["records"]))
        self.assertTrue(any(r.get("topic")=="baseline-counterfactual" for r in c["records"]))

if __name__=="__main__":
    unittest.main(verbosity=2)
