import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import plan42_estate_handoff as est
from plan42_bridge import ROOT,GENERATED,SCHEMA as BS

SPEC='tests/preferred_capabilities_smoke.plan42.json'

class TestEstateHandoff(unittest.TestCase):
    def test_manifest_candidate_only(self):
        m=est.estate_manifest()
        self.assertEqual(m['status'],'UNREGISTERED_CANDIDATE')
        self.assertFalse(m['plan42_service']['estate_runtime_registry_published'])
        self.assertEqual(m['estate_corpus']['component_records'],176)
        self.assertEqual(len(m['source_artifacts']),10)
    def test_handoff_no_side_effects(self):
        result=est.handoff(SPEC)
        self.assertTrue(result['ok'])
        self.assertIsNone(result['source']['semantic_source_store_revision'])
        self.assertEqual(result['source']['source_authority'],'UNATTESTED_LOCAL')
        self.assertEqual(result['evidence_class'],'LOCAL_UNVERIFIED_CANDIDATE')
        self.assertEqual(set(result['required_gates'].values()),{False})
        self.assertIsNone(result['compiler_receipt'])
    def test_outside_source_refused(self):
        with self.assertRaises(ValueError):est.handoff('../../outside.json')
    def test_receipt_source_changed_refused(self):
        with tempfile.NamedTemporaryFile(mode='w',dir=ROOT,suffix='.json') as f:
            json.dump({'schema':BS,'ok':True,'operation':'compile','source_sha256':'bad'},f);f.flush()
            with self.assertRaises(ValueError):est.handoff(SPEC, f.name)
    def test_receipt_claims_execution_refused(self):
        inspection=est.handoff(SPEC)
        with tempfile.NamedTemporaryFile(mode='w',dir=ROOT,suffix='.json') as f:
            json.dump({'schema':BS,'ok':True,'operation':'compile',
                       'source_sha256':inspection['source']['sha256'],
                       'executed':True,'published':False,'dispatched':False},f);f.flush()
            with self.assertRaisesRegex(ValueError,'no-execute'):
                est.handoff(SPEC, f.name)
    def test_receipt_wrong_output_refused(self):
        source=est.handoff(SPEC)['source']['sha256']
        with tempfile.NamedTemporaryFile(mode='w',dir=ROOT,suffix='.json') as f:
            json.dump({'schema':BS,'ok':True,'operation':'compile',
                       'status':'generated','source_sha256':source,
                       'executed':False,'published':False,'dispatched':False,
                       'output':'tools/plan42c.py','output_sha256':'whatever'},f);f.flush()
            with self.assertRaisesRegex(ValueError,'staging root'):
                est.handoff(SPEC, f.name)
    def test_receipt_valid_only_local_proof(self):
        GENERATED.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=GENERATED) as d:
            artifact=Path(d)/'generated.py';artifact.write_text('print(1)\n')
            with tempfile.NamedTemporaryFile(mode='w',dir=ROOT,suffix='.json') as f:
                json.dump({'schema':BS,'ok':True,'operation':'compile','status':'generated',
                           'source_sha256':est.handoff(SPEC)['source']['sha256'],
                           'executed':False,'published':False,'dispatched':False,
                           'output':str(artifact.relative_to(ROOT)),
                           'output_sha256':est.digest(artifact),'engine':'python-canonical'},f);f.flush()
                r=est.handoff(SPEC,f.name)
                self.assertEqual(r['compiler_receipt']['verified'],'LOCAL_DIGEST_ONLY')
                self.assertFalse(r['required_gates']['runtime_registry_publication'])
    def test_pin_mismatches_fail(self):
        with tempfile.TemporaryDirectory() as d:
            r=est.verify_archives(Path(d))
            self.assertFalse(r['ok'])
            self.assertTrue(all(x['status']=='MISSING' for x in r['packages']))
    def test_manifest_no_queue_obligation(self):
        m=est.estate_manifest()
        self.assertFalse(m['source_qualification']['queuing_required'])
    def test_no_claimed_hot_upgrade(self):
        m=est.estate_manifest()
        self.assertFalse(m['source_qualification']['hot_upgrade'])
if __name__=='__main__':unittest.main()
