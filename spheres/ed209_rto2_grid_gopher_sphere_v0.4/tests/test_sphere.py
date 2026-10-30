import json
import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/"packs"/"ed209-rto2-grid"

class SphereTest(unittest.TestCase):
    def test_manifest(self):
        m=json.loads((ROOT/"integration.json").read_text())
        self.assertEqual(m["schema"],"alchemy.autobuild.integration/0.2")
        self.assertEqual(m["package"]["version"],"0.4")
        self.assertEqual(m["publish"]["tree"]["path"],"spheres/ed209_rto2_grid_gopher_sphere_v0.4")

    def test_profile(self):
        p=json.loads((ROOT/"profiles"/"ed209-rto2-grid.json").read_text())
        self.assertEqual(p["id"],"ed209-rto2-grid")
        self.assertEqual(p["version"],"0.4")

    def test_sphere_and_articles(self):
        m=json.loads((PACK/"00-sphere.json").read_text())
        self.assertEqual(m["version"],"0.4")
        self.assertIn("ed.identity",m["start_here"])
        for article_id in m["start_here"]:
            obj=json.loads((PACK/"articles"/(article_id+".json")).read_text())
            self.assertEqual(obj["id"],article_id)
            self.assertEqual(obj["kind"],"article")
            self.assertEqual(obj["sphere"],m["id"])
            self.assertTrue(obj["invariants"])
            self.assertTrue(obj["provenance"])
            for src in obj["provenance"]:
                self.assertEqual(len(src["sha256"]),64)

    def test_no_false_live_acceptance(self):
        doc=(ROOT/"README.md").read_text().lower()
        self.assertIn("no confirmed live 20/20",doc)
        self.assertIn("sshnode.sh",doc)
        self.assertIn("not thereby field-qualified",doc)

    def test_identity_boundary(self):
        obj=json.loads((PACK/"articles"/"ed.identity.json").read_text())
        joined=" ".join(obj["invariants"])
        self.assertIn("Authentication attribution is not authorization",joined)
        self.assertIn("IdentityDirectory aclDecision",joined)
        self.assertIn("PERMISSION_DENIED",joined)
        self.assertIn("ConnectSelector remains connector authority",joined)

    def test_continuity(self):
        corpus=json.loads((PACK/"corpora"/"ed209-continuity.json").read_text())
        ids={r["id"] for r in corpus["records"]}
        self.assertTrue({"minimum-is-not-field-estate","mu-is-not-worker","advice-is-not-lease","managed-target-is-not-mi"}.issubset(ids))

if __name__=="__main__":
    unittest.main()
