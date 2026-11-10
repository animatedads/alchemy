"""Sphere v0.2 source/qualification policy tests, NOT live-host probes."""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
class SphereTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sphere=read('packs/rasenfalcon/00-sphere.json')
        cls.articles={p.stem:json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'packs/rasenfalcon/articles').glob('*.json')}
    def test_manifest_profile_version(self):
        manifest=read('integration.json')
        self.assertEqual(manifest['publish']['tree']['path'],'spheres/rasenfalcon_v0.2')
        self.assertEqual(manifest['package']['version'],'0.2')
        self.assertEqual(self.sphere['version'],'0.2')
        self.assertEqual(read('profiles/rasenfalcon.json')['id'],'rasenfalcon')
        self.assertEqual(len(self.articles),13)
    def test_provenance_and_start_topics(self):
        sections={s['id'] for s in self.sphere['sections']}
        for key,a in self.articles.items():
            self.assertEqual(key,a['id'])
            self.assertIn(a['section'],sections)
            self.assertEqual(a['kind'],'article')
            self.assertEqual(a['sphere'],'rasenfalcon')
            self.assertTrue(a['invariants'])
            for proof in a['provenance']:
                self.assertEqual(len(proof['sha256']),64)
                self.assertTrue(all(c in '0123456789abcdef' for c in proof['sha256']))
                self.assertTrue(proof['member'])
        for x in self.sphere['start_here']: self.assertIn(x,self.articles)
    def test_no_fallback_private_https(self):
        a=self.articles['rasenfalcon.private-tls']
        self.assertEqual(a['client_auth'],'mTLS_REQUIRED')
        self.assertEqual(a['fallback'],'FORBIDDEN')
        self.assertEqual(len(set(a['units'])),2)
        txt=' '.join(a['invariants']).lower()
        for x in ('no cert','wrong ca','revoked','sni','password-only','public ca'):
            self.assertIn(x,txt)
    def test_gateway_exact_targets(self):
        self.assertEqual(self.articles['rasenfalcon.gateway']['targets'],{'tn3270':['ed209zz','ed209z'],'web':['ed209cray','ed209tops']})
    def test_publish_status_does_not_imply_live(self):
        a=self.articles['rasenfalcon.start']['status']
        self.assertEqual(a['github_source'],'PRESENT_ON_MAIN_V0.4')
        self.assertEqual(a['v042_candidate'],'SUBMITTED_NOT_ACCEPTED')
        self.assertEqual(a['mTLS_live'],'NOT_RUN')
        self.assertEqual(a['CMS_publication'],'NOT_QUALIFIED')
        self.assertEqual(a['production_site'],'NOT_DEPLOYED')
        self.assertEqual(self.articles['rasenfalcon.qualification']['native_services'],'NOT_RUN')
    def test_publisher_stage_fail_closed(self):
        a=self.articles['rasenfalcon.publisher-handoff']
        self.assertEqual(a['site'],'rasenfalcon.com')
        self.assertEqual(a['stage_schema'],'rasenfalcon.publisher-stage/0.1')
        self.assertEqual(a['production'],'DENIED')
        self.assertEqual(a['tests_declared'],18)
        self.assertEqual(a['tests_independently_executed'],'NOT_RUN')
        self.assertFalse(a['native_revision_verified'])
        tx=' '.join(a['invariants']).lower()
        for x in ('candidate','noindex','production','nine page','no cms/wire receipts'):
            self.assertIn(x,tx)
    def test_tester_evidence_gated(self):
        a=self.articles['rasenfalcon.test-coordination']
        self.assertEqual(a['component'],'rasenfalcon-website')
        self.assertEqual(a['nonexecution_reply'],'REQ-00000825')
        self.assertEqual(a['corrected_test_request'],'REQ-00000943')
        self.assertEqual(a['execution'],'NOT_RUN')
        self.assertEqual(a['approval'],'REQUIRED_FROM_OWNER')
    def test_scheduler_and_lifecycle(self):
        t=' '.join(self.articles['rasenfalcon.scheduling']['invariants']).lower()
        self.assertIn('no system crond',t)
        self.assertIn('systemd minute timer',t)
        self.assertIn('withdraws no-longer-owned listeners',' '.join(self.articles['rasenfalcon.capability-lifecycle']['invariants']))
    def test_source_hashes(self):
        a=self.articles['rasenfalcon.source-map']
        self.assertEqual(set(a['issue_numbers']),set(range(6,15)))
        self.assertEqual(len(a['artifact_hashes']),6)
        for digest in a['artifact_hashes'].values():
            self.assertEqual(len(digest),64)
if __name__=='__main__':unittest.main()
