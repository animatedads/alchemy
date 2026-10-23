import json
import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/"packs"/"customer-service-agents"
ART=PACK/"articles"
READ=lambda p:json.loads(p.read_text(encoding="utf-8"))

class SphereQualification(unittest.TestCase):
  @classmethod
  def setUpClass(cls):
    cls.meta=READ(PACK/"00-sphere.json")
    cls.policy=READ(PACK/"01-access-policy.json")
    cls.profile=READ(ROOT/"profiles"/"customer-service-agents.json")
    cls.articles=[READ(p) for p in sorted(ART.glob("*.json"))]
  def test_sphere_identity(self):
    self.assertEqual(self.meta["kind"],"sphere")
    self.assertEqual(self.meta["id"],"customer-service-agents")
    self.assertEqual(self.meta["access_policy"],self.policy["id"])
  def test_profile(self):
    self.assertIn("packs/customer-service-agents",self.profile["packs"])
    self.assertIn("packs/core",self.profile["packs"])
  def test_article_id_uniqueness(self):
    ids=[a["id"] for a in self.articles]
    self.assertEqual(len(ids),len(set(ids)))
    self.assertEqual(len(ids),10)
    self.assertTrue(set(self.meta["start_here"])<=set(ids))
  def test_article_contracts(self):
    for a in self.articles:
      self.assertEqual(a["kind"],"article")
      self.assertEqual(a["sphere"],self.meta["id"])
      self.assertTrue(a["summary"] and a["invariants"] and a["procedure"])
      for p in a["provenance"]:
        self.assertRegex(p["sha256"],r"^[0-9a-f]{64}$")
        self.assertTrue(p["artifact"] and p["claim"])
  def test_qualification_truth(self):
    a=next(x for x in self.articles if x["id"]=="qual.customer-service.current")
    text=" ".join(a["invariants"])
    for item in ("20 Python","11 Python","227 MP4","not real MediaPipe","receipt was absent"):
      self.assertIn(item,text)
  def test_no_unfounded_asset_approval(self):
    s=" ".join(" ".join(a["invariants"]) for a in self.articles)
    for phrase in ("never automatic approval","not proof of spoken content","No source-backed claim"):
      self.assertIn(phrase,s)
  def test_migration_boundaries(self):
    a=next(x for x in self.articles if x["id"]=="arch.customer-service.video-mesh")
    s=" ".join(a["invariants"]+a["procedure"])
    for term in ("Storage Fabric","Migratable Job","Job-to-Node","PTS","checkpoint"):
      self.assertIn(term,s)
  def test_readback_counts(self):
    a=next(x for x in self.articles if x["id"]=="ops.customer-service.capture")
    self.assertIn("72",a["summary"]+" "+" ".join(a["invariants"]))
    b=next(x for x in self.articles if x["id"]=="ops.customer-service.legacy-recovery")
    self.assertIn("83",b["summary"])
    self.assertIn("227",b["summary"])
if __name__=="__main__":
  unittest.main()
