import json
import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/"packs"/"ed209-rto2-grid"

class SphereTest(unittest.TestCase):
    def test_manifest(self):
        m=json.loads((ROOT/"integration.json").read_text())
        self.assertEqual(m["schema"],"alchemy.autobuild.integration/0.2")
        self.assertEqual(m["package"]["version"],"0.2")
        self.assertEqual(m["publish"]["tree"]["path"],"spheres/ed209_rto2_grid_gopher_sphere_v0.1")

    def test_profile(self):
        p=json.loads((ROOT/"profiles"/"ed209-rto2-grid.json").read_text())
        self.assertEqual(p["id"],"ed209-rto2-grid")
        self.assertEqual(p["version"],"0.2")
        self.assertIn("packs/ed209-rto2-grid",p["packs"])

    def test_sphere_and_articles(self):
        m=json.loads((PACK/"00-sphere.json").read_text())
        self.assertEqual(m["id"],"ed209-rto2-grid")
        self.assertEqual(m["version"],"0.2")
        for required in ("ed.controller","ed.integration","ed.backlog"):
            self.assertIn(required,m["start_here"])
        for i in m["start_here"]:
            obj=json.loads((PACK/"articles"/(i+".json")).read_text())
            self.assertEqual(obj["id"],i)
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
        self.assertIn("ten mus and twenty mis",doc)
        self.assertIn("8 mus + 16 mis",doc)

    def test_current_controller_non_conflation(self):
        obj=json.loads((PACK/"articles"/"ed.current.json").read_text())
        joined=" ".join(obj["invariants"]).lower()
        self.assertIn("8-mu/16-mi",joined)
        self.assertIn("ten mus",joined)
        controller=json.loads((PACK/"articles"/"ed.controller.json").read_text())
        text=" ".join(controller["invariants"]).lower()
        self.assertIn("does not own placement",text)
        self.assertIn("not inferred from mi rows",text)

    def test_integration_non_authority(self):
        obj=json.loads((PACK/"articles"/"ed.integration.json").read_text())
        text=" ".join(obj["invariants"]).lower()
        self.assertIn("advisory",text)
        self.assertIn("not automatic mi estate members",text)
        self.assertIn("production dispatch remains disabled",text)

    def test_continuity(self):
        corpus=json.loads((PACK/"corpora"/"ed209-continuity.json").read_text())
        self.assertEqual(corpus["sphere"],"ed209-rto2-grid")
        ids={r["id"] for r in corpus["records"]}
        self.assertTrue({"minimum-is-not-field-estate","mu-is-not-worker","advice-is-not-lease","managed-target-is-not-mi"}.issubset(ids))

if __name__=="__main__":
    unittest.main()
