import hashlib,json,pathlib,subprocess,sys,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'bin'))
from controller_commit import publish,check
from run_20mi import TARGETS,verified
class ControllerTests(unittest.TestCase):
 def setUp(self):
  t=tempfile.TemporaryDirectory();self.addCleanup(t.cleanup);self.root=pathlib.Path(t.name)
 def receipt(self,mi='MN1-ED209F',mu='MU-ED209F',run='T1'):
  v=500500
  return dict(schema='ed209.rto2.controller-receipt/1',run_id=run,mi_id=mi,mu_id=mu,
    controller_id='GRID.MU.'+mu,delivery='authenticated-xtp-qf-wire-response',response_correlation='RTO2-a1',
    rto2=dict(schema='rexxos.rto2.smoke.result/1',run_id=run,node_id=mi,n=1000,value=v,
      committed_value=v,committed_sequence=1,epoch=1,role='ACTIVE',rto2_api='alchemy.rto/0.1',
      rto2_lifecycle='CAPTURED',rto2_identity=f'ED209.SMOKE.{run}:{mi}',rto2_state=dict(value=v,committedValue=v)))
 def test_routes(self):
  self.assertEqual(20,len(TARGETS));self.assertEqual(list(range(1,21)),[x[0] for x in TARGETS])
  self.assertEqual(20,len({x[3] for x in TARGETS}))
  self.assertEqual((17,'ed209f','MU-ED209F','MN1-ED209F'),TARGETS[16])
  self.assertEqual((20,'ed209h','MU-ED209H','MN2-ED209H'),TARGETS[19])
 def test_commit_idempotence(self):
  a=publish(self.root,self.receipt(),'T1','MN1-ED209F','MU-ED209F',1000,1)
  b=publish(self.root,self.receipt(),'T1','MN1-ED209F','MU-ED209F',1000,1)
  self.assertEqual(a,b)
  self.assertEqual(500500,verified(a,17,'ed209f','MU-ED209F','MN1-ED209F','T1',1000,1)['value'])
 def test_wrong_commit_rejected(self):
  for field,value in [('committed_value',33),('committed_sequence',0),('epoch',3),('rto2_api','madeup')]:
   obj=self.receipt();obj['rto2'][field]=value
   with self.subTest(field=field),self.assertRaises(ValueError):check(obj,'T1','MN1-ED209F','MU-ED209F',1000,1)
 def test_wrong_mi_rejected(self):
  obj=self.receipt();obj['mi_id']='MN2-ED209F'
  with self.assertRaises(ValueError):check(obj,'T1','MN1-ED209F','MU-ED209F',1000,1)
 def test_bad_digest_rejected(self):
  obj=publish(self.root,self.receipt(),'T1','MN1-ED209F','MU-ED209F',1000,1)
  obj['receipt_sha256']='0'*64
  with self.assertRaisesRegex(ValueError,'digest'):verified(obj,17,'ed209f','MU-ED209F','MN1-ED209F','T1',1000,1)
 def test_dry_run(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/run_20mi.py'),'--run','DRY','--output',str(self.root/'out'),'--dry-run'],text=True,capture_output=True)
  self.assertEqual(0,p.returncode,p.stderr);self.assertEqual(20,p.stdout.count('PLAN route='))
  self.assertFalse((self.root/'out').exists())
 def test_mock_full_fleet_then_missing_result(self):
  ledger=self.root/'mock';ledger.mkdir()
  for route,host,mu,mi in TARGETS:
   obj=publish(ledger,self.receipt(mi,mu,'R20'),'R20',mi,mu,1000,1)
   (ledger/(host+'.'+mi+'.json')).write_text(json.dumps(obj))
  ssh=self.root/'sshnode'
  ssh.write_text('#!/usr/bin/env python3\nimport pathlib,sys\nhost=sys.argv[1];parts=sys.argv[2].split();mi=parts[3]\np=pathlib.Path('+repr(str(ledger))+')/(host+"."+mi+".json");print(p.read_text())\n')
  ssh.chmod(0o700)
  base=[sys.executable,str(ROOT/'bin/run_20mi.py'),'--sshnode',str(ssh),'--run','R20']
  p=subprocess.run(base+['--output',str(self.root/'sorted')],capture_output=True,text=True)
  self.assertEqual(0,p.returncode,p.stderr)
  self.assertEqual(20,json.loads((self.root/'sorted/summary.json').read_text())['completed'])
  (ledger/'ed209h.MN2-ED209H.json').unlink()
  p=subprocess.run(base+['--output',str(self.root/'broken')],capture_output=True,text=True)
  self.assertEqual(1,p.returncode)
  self.assertEqual('FAIL',json.loads((self.root/'broken/summary.json').read_text())['status'])
if __name__=='__main__':unittest.main()
