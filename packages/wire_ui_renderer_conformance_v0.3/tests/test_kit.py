import json,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; COMPARE=ROOT/'tools/compare_transcript.py'; REF=ROOT/'tools/reference_adapter.py'; CANON=ROOT/'fixtures/canonical_input.json'; EXPECTED=ROOT/'fixtures/expected_transcript.json'
class KitTests(unittest.TestCase):
 def cmd(self,*a): return subprocess.run(['python3',*map(str,a)],text=True,capture_output=True)
 def test_reference_adapter_matches(self):
  with tempfile.TemporaryDirectory() as td:
   out=Path(td)/'actual.json'; self.assertEqual(self.cmd(REF,CANON,out).returncode,0); p=self.cmd(COMPARE,EXPECTED,out); self.assertEqual(p.returncode,0,p.stderr)
 def invalid(self,name,needle):
  p=self.cmd(COMPARE,ROOT/'fixtures'/name,ROOT/'fixtures'/name); self.assertEqual(p.returncode,3); self.assertIn(needle,p.stderr)
 def test_row_ordinal_rejected(self): self.invalid('nonconforming_row_ordinal.json','stable application identity')
 def test_resource_url_rejected(self): self.invalid('nonconforming_resource_url.json','forbidden')
 def test_workspace_context_required(self): self.invalid('nonconforming_workspace_context.json','workspaceContext')
 def test_range_request_bounded(self): self.invalid('nonconforming_range_request.json','bounded')
 def test_expected_is_valid(self):
  p=self.cmd(COMPARE,EXPECTED,EXPECTED); self.assertEqual(p.returncode,0,p.stderr)
 def test_status_is_honest(self):
  s=json.loads((ROOT/'STATUS.json').read_text()); self.assertFalse(any(v['pass'] for v in s['renderers'].values()))
  self.assertEqual(s['status'],'PARTIAL_REAL_RENDERER_EVIDENCE')
 def test_real_head_evidence_is_explicit(self):
  e=json.loads((ROOT/'qualification/REAL_RENDERER_HEADS_20261029.json').read_text())
  self.assertEqual(e['heads']['swing']['version'],'0.2-dev12')
  self.assertTrue(e['heads']['swing']['gates']['bounded-range-request'])
  self.assertFalse(e['heads']['swing']['gates']['exact-published-resource-ref'])
  self.assertTrue(e['heads']['gtk-direct-linux']['gates']['stable-collection-identity'])
  self.assertFalse(e['heads']['gtk-direct-linux']['gates']['revision-ordering'])
 def test_rasenfalcon_readiness_fails_closed(self):
  r=json.loads((ROOT/'qualification/RASENFALCON_RUNTIME_READINESS_20261029.json').read_text())
  self.assertEqual(r['status'],'NOT_READY')
  self.assertTrue(r['gates']['review_stage_materialised'])
  self.assertFalse(r['gates']['exact_https_0_4_8_runtime_qualified'])
  self.assertFalse(r['gates']['ldap_installed'])
if __name__=='__main__': unittest.main()
