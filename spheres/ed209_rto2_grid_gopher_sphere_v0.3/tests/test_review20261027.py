"""Source and review acceptance nonclaims for ED209 v0.3 sphere."""
import json
import pathlib
import unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Review(unittest.TestCase):
    def test_revision(self):
        m=json.loads((ROOT/"integration.json").read_text())
        self.assertEqual(m["package"]["version"],"0.3")
        self.assertEqual(m["publish"]["tree"]["path"],"spheres/ed209_rto2_grid_gopher_sphere_v0.3")
    def test_r10_r11_remain_distinct(self):
        obj=json.loads((ROOT/"packs/ed209-rto2-grid/articles/ed.review20261027.json").read_text())
        joined=" ".join(obj["invariants"])
        self.assertIn("R-10",joined)
        self.assertIn("R-11",joined)
        self.assertIn("symmetric key",joined)
        self.assertIn("20/20",joined)
    def test_no_field_claim(self):
        s=(ROOT/"qualification/STATUS.md").read_text()
        self.assertIn("NOT ACCEPTED",s)
        self.assertIn("timed out",s)
if __name__=="__main__":unittest.main()
