import pathlib, unittest, json
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ValidityContract(unittest.TestCase):
 def test_contract(self):
  c=json.loads((ROOT/'contracts/time-validity-v0.10.json').read_text())
  self.assertEqual(c['schema'],'single.time.validity/0.1')
  self.assertFalse(c['authorisesCredentialUse'])
  self.assertFalse(c['networkExposure'])
 def test_source_owns_no_security_admission(self):
  t=(ROOT/'src/TimeValidityWindow.cls').read_text()
  self.assertIn('INDETERMINATE',t)
  self.assertIn('TimeClockInterval',t)
  self.assertIn("result['authorisesUse'] = .false",t)
  self.assertNotIn('::method send',t)
  self.assertNotIn('::method validateCertificate',t)
if __name__=='__main__':unittest.main()
