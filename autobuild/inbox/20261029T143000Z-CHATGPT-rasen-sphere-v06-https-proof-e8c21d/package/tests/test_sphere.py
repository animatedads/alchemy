"""Static sphere/provenance qualification only; does not test deployed services."""
import json
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT / p).read_text())
class SphereTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sphere = read("packs/rasenfalcon/00-sphere.json")
        cls.a = {p.stem:json.loads(p.read_text()) for p in (ROOT/"packs/rasenfalcon/articles").glob("*.json")}
    def test_manifest_and_profile(self):
        self.assertEqual(read("integration.json")["publish"]["tree"]["path"],"spheres/rasenfalcon_v0.6")
        self.assertIn("packs/rasenfalcon",read("profiles/rasenfalcon.json")["packs"])
        self.assertEqual(len(self.a),15)
    def test_article_provenance(self):
        sections={s["id"] for s in self.sphere["sections"]}
        for key,a in self.a.items():
            self.assertEqual(a["id"],key)
            self.assertEqual(a["kind"],"article")
            self.assertEqual(a["sphere"],"rasenfalcon")
            self.assertIn(a["section"],sections)
            self.assertTrue(a["invariants"])
            for p in a["provenance"]:
                self.assertRegex(p["sha256"],r"^[a-f0-9]{64}$")
                self.assertTrue(p["artifact"] and p["member"])
        for k in self.sphere["start_here"]: self.assertIn(k,self.a)
    def test_private_service_fail_closed(self):
        a=self.a["rasenfalcon.private-tls"]
        self.assertEqual(a["fallback"],"FORBIDDEN")
        self.assertEqual(a["client_auth"],"mTLS_REQUIRED")
        self.assertEqual(len(set(a["units"])),2)
        joined=" ".join(a["invariants"]).lower()
        for needle in ("no cert","wrong ca","revoked","sni","password-only","public ca"):
            self.assertIn(needle,joined)
    def test_gateway_target_names(self):
        self.assertEqual(self.a["rasenfalcon.gateway"]["targets"],{"tn3270":["ed209zz","ed209z"],"web":["ed209cray","ed209tops"]})
    def test_published_does_not_mean_live(self):
        s=self.a["rasenfalcon.start"]["status"]
        self.assertEqual(s["github_source"],"V0.4.5_SUBMITTED_VIA_GIT")
        self.assertEqual(s["mTLS_live"],"NOT_RUN")
        self.assertEqual(s["CMS_publication"],"NOT_QUALIFIED")
        self.assertEqual(self.a["rasenfalcon.qualification"]["native_services"],"NOT_RUN")
    def test_scheduler_and_least_presence(self):
        b=" ".join(self.a["rasenfalcon.scheduling"]["invariants"]).lower()
        self.assertIn("systemd minute timer",b)
        self.assertIn("no system crond",b)
        c=" ".join(self.a["rasenfalcon.capability-lifecycle"]["invariants"])
        self.assertIn("withdraws no-longer-owned listeners",c)
    def test_site_publication_receipt_boundary(self):
        a=self.a["rasenfalcon.website-publication"]
        self.assertEqual(a["state"]["production"],"BLOCKED")
        self.assertEqual(a["state"]["cms_service"],"NOT_IMPLEMENTED")
        self.assertEqual(a["state"]["wire_release"],"NOT_QUALIFIED")
        self.assertEqual(len(a["published_source_paths"]),2)
        self.assertIn("noindex,nofollow"," ".join(a["invariants"]))
        self.assertIn("receipt verifier"," ".join(a["invariants"]).lower())
        self.assertEqual(self.a["rasenfalcon.public-site"]["CMS_state"],"NOT_QUALIFIED")
        self.assertEqual(self.a["rasenfalcon.qualification"]["native_services"],"NOT_RUN")
    def test_candidate_editor_bridge_does_not_escalate_authority(self):
        a=self.a["rasenfalcon.website-publication"]
        bridge=a["publisher_to_site_bridge"]
        self.assertEqual(bridge["authority"],"CANDIDATE_UNREVIEWED")
        self.assertFalse(bridge["native_revision_verified"])
        self.assertEqual(len(bridge["accepted"]),2)
        self.assertIn("DENIED",bridge["production"])
        self.assertEqual(a["state"]["production"],"BLOCKED")
        self.assertEqual(a["state"]["cms_service"],"NOT_IMPLEMENTED")
        self.assertEqual(self.a["rasenfalcon.qualification"]["native_services"],"NOT_RUN")
    def test_local_stage_not_host_install_or_release(self):
        d=self.a["rasenfalcon.deployment-stage"]
        self.assertEqual(d["stage"]["state"],"STAGED_VERIFIED")
        self.assertEqual(d["stage"]["pages"],9)
        self.assertEqual(d["stage"]["files"],15)
        self.assertEqual(d["installation"]["state"],"NOT_PERFORMED")
        self.assertEqual(d["running"]["state"],"NOT_OBSERVED")
        self.assertEqual(d["production"],"BLOCKED")
        self.assertEqual(d["qualification"]["independent_v043"],"PASS_REQ-00001283_AND_00001289")
    def test_public_https_integrity_evidence(self):\n        q=self.a["rasenfalcon.live-https-integrity"]\n        self.assertEqual(q["path_count"],13)\n        self.assertEqual(q["local_tls_tests"],"9_PASS")\n        self.assertEqual(q["public_https_live"],"NOT_RUN")\n        self.assertEqual(q["native_server_installed"],"NOT_OBSERVED")\n        self.assertEqual(q["production_release"],"BLOCKED")\n    def test_independent_v043_retest(self):\n        q=self.a["rasenfalcon.qualification"]["independent_v043_retest"]\n        self.assertEqual(q["website"],"18/18 PASS")\n        self.assertEqual(q["handoff"],"21/21 PASS")\n        self.assertEqual(q["production_gate"],"DENIED_AS_DESIGNED")\n    def test_source_hashes(self):
        for x in self.a["rasenfalcon.source-map"]["artifact_hashes"].values():
            self.assertRegex(x,r"^[0-9a-f]{64}$")
        self.assertEqual(self.a["rasenfalcon.source-map"]["issue_numbers"],list(range(6,15)))
if __name__=="__main__": unittest.main()
