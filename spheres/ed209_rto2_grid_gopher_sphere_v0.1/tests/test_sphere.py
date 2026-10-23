import json
import pathlib
import unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/"packs"/"ed209-rto2-grid"
class SphereTest(unittest.TestCase):
    def test_manifest(self):
        m=json.loads((ROOT/"integration.json").read_text())
        self.assertEqual(m["schema"],"alchemy.autobuild.integration/0.2")
        self.assertEqual(m["publish"]["tree"]["path"],"spheres/ed209_rto2_grid_gopher_sphere_v0.1")
    def test_profile(self):
        p=json.loads((ROOT/"profiles"/"ed209-rto2-grid.json").read_text())
        self.assertEqual(p["id"],"ed209-rto2-grid")
        self.assertIn("packs/ed209-rto2-grid",p["packs"])
    def test_sphere_and_articles(self):
        m=json.loads((PACK/"00-sphere.json").read_text())
        self.assertEqual(m["id"],"ed209-rto2-grid")
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
    def test_continuity(self):
        corpus=json.loads((PACK/"corpora"/"ed209-continuity.json").read_text())
        self.assertEqual(corpus["sphere"],"ed209-rto2-grid")
        self.assertGreaterEqual(len(corpus["records"]),5)
if __name__=="__main__":unittest.main()
