import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

BASE=pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0,str(BASE/'bin'))
from controller_commit import publish,check
from run_20mi import TARGETS,check_receipt

class Contracts(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup)
        self.root=pathlib.Path(self.t.name)
    def sample(self,mi='MN1-ED209F',mu='MU-ED209F',run='T1'):
        val=500500
        return {'schema':'ed209.rto2.controller-receipt/1','run_id':run,'mi_id':mi,'mu_id':mu,
                'controller_id':'GRID.MU.'+mu,'delivery':'authenticated-xtp-qf-wire-response','response_correlation':'RTO2-a1',
                'rto2':{'schema':'rexxos.rto2.smoke.result/1','run_id':run,'node_id':mi,'n':1000,'value':val,
                 'committed_value':val,'committed_sequence':1,'epoch':1,'role':'ACTIVE','rto2_api':'alchemy.rto/0.1',
                 'rto2_lifecycle':'CAPTURED','rto2_identity':f'ED209.SMOKE.{run}:{mi}',
                 'rto2_state':{'value':val,'committedValue':val}}}
    def test_20_unique_targets(self):
        self.assertEqual(20,len(TARGETS));self.assertEqual(list(range(1,21)),[x[0] for x in TARGETS]);self.assertEqual(20,len(set(x[3] for x in TARGETS)))
        self.assertEqual((17,'ed209f','MU-ED209F','MN1-ED209F'),TARGETS[16]);self.assertEqual((20,'ed209h','MU-ED209H','MN2-ED209H'),TARGETS[19])
    def test_durable_commit_and_idempotence(self):
        d=self.sample();a=publish(self.root,d,'T1','MN1-ED209F','MU-ED209F',1000,1)
        b=publish(self.root,d,'T1','MN1-ED209F','MU-ED209F',1000,1)
        self.assertEqual(a,b);self.assertEqual(500500,a['rto2']['committed_value']);self.assertEqual('DURABLE_LOCAL_RECEIPT',a['controller_commit'])
        check_receipt(a,17,'ed209f','MU-ED209F','MN1-ED209F','T1',1000,1)
        bad=dict(d);bad['response_correlation']='DIFFERENT'
        with self.assertRaisesRegex(ValueError,'immutable'):publish(self.root,bad,'T1','MN1-ED209F','MU-ED209F',1000,1)
    def test_reject_uncommitted_wrong_node_controller(self):
        r=self.sample()
        for field,bad in [('committed_sequence',0),('committed_value',10),('epoch',2),('rto2_identity','bogus'),('rto2_api','made-up')]:
            x=json.loads(json.dumps(r));x['rto2'][field]=bad
            with self.subTest(field=field),self.assertRaises(ValueError):check(x,'T1','MN1-ED209F','MU-ED209F',1000,1)
        for field,bad in [('controller_id','GRID.MU.MU-ED209H'),('mi_id','MN2-ED209F'),('delivery','unverified')]:
            x=json.loads(json.dumps(r));x[field]=bad
            with self.subTest(field=field),self.assertRaises(ValueError):check(x,'T1','MN1-ED209F','MU-ED209F',1000,1)
    def test_sort_rejects_forged_digest(self):
        a=publish(self.root,self.sample(),'T1','MN1-ED209F','MU-ED209F',1000,1)
        a['receipt_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'digest'):check_receipt(a,17,'ed209f','MU-ED209F','MN1-ED209F','T1',1000,1)
    def test_dry_run_lists_20_without_network(self):
        p=subprocess.run([sys.executable,str(BASE/'bin/run_20mi.py'),'--run','T2','--output',str(self.root/'out'),'--dry-run'],capture_output=True,text=True)
        self.assertEqual(0,p.returncode,p.stderr);self.assertEqual(20,p.stdout.count('PLAN route='));self.assertFalse((self.root/'out').exists())
    def test_staged_controller_grant(self):
        auth=self.root/'auth';(auth/'nodes/MN1-ED209H').mkdir(parents=True);(auth/'mus/MU-ED209H').mkdir(parents=True)
        (auth/'nodes/MN1-ED209H/node.env').write_text('GRID_NODE_ID=MN1-ED209H\nGRID_MU_ID=MU-ED209H\nGRID_MU_KEY_HEX='+('ab'*32)+'\n')
        (auth/'mus/MU-ED209H/mu.env').write_text('GRID_MU_MAC=02:52:00:0a:00:01\n')
        (auth/'nodes/MN1-ED209H/peers.manifest').write_text('example|row\n')
        from importlib.machinery import SourceFileLoader
        import importlib.util
        p=BASE/'ops/stage_mi_controller_trust.py';spec=importlib.util.spec_from_file_location('trust',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
        result=self.root/'new.manifest';m.stage(auth,'MN1-ED209H',result)
        self.assertIn('GRID.MU.MU-ED209H|grid-controller|k1|',result.read_text())
        with self.assertRaisesRegex(ValueError,'refusing'):m.stage(auth,'MN1-ED209H',result)
    def test_full_fleet_sorted_receipts_mocked_not_live(self):
        # Synthetic fixture for gate logic ONLY. Absolutely not a field qualification.
        ledger=self.root/'mock';ledger.mkdir()
        for route,host,mu,mi in TARGETS:
            row=publish(ledger,self.sample(mi,mu,'T20'),'T20',mi,mu,1000,1)
            (ledger/(host+'.'+mi+'.json')).write_text(json.dumps(row))
        ssh=self.root/'mock-sshnode'
        ssh.write_text('#!/usr/bin/env python3\nimport json,sys,pathlib\nhost=sys.argv[1];parts=sys.argv[2].split();mi=parts[3];p=pathlib.Path('+repr(str(ledger))+')/(host+"."+mi+".json");print(p.read_text())\n')
        ssh.chmod(0o700)
        cmd=[sys.executable,str(BASE/'bin/run_20mi.py'),'--sshnode',str(ssh),'--run','T20','--output',str(self.root/'sorted')]
        p=subprocess.run(cmd,capture_output=True,text=True)
        self.assertEqual(0,p.returncode,p.stderr)
        report=json.loads((self.root/'sorted/summary.json').read_text());self.assertEqual('PASS',report['status']);self.assertEqual(20,report['completed'])
        self.assertEqual([*range(1,21)],[x['route'] for x in report['results']])
        (ledger/'ed209h.MN2-ED209H.json').unlink()
        p=subprocess.run(cmd[:-1]+[str(self.root/'broken')],capture_output=True,text=True)
        self.assertEqual(1,p.returncode);self.assertEqual('FAIL',json.loads((self.root/'broken/summary.json').read_text())['status'])

if __name__=='__main__':unittest.main()
