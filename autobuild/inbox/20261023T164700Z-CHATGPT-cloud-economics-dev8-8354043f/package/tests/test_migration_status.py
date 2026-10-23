#!/usr/bin/env python3
import copy
import importlib.machinery
import importlib.util
import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TOOL=ROOT/'tools'/'migration-status-observer'
loader=importlib.machinery.SourceFileLoader('statusobs',str(TOOL))
spec=importlib.util.spec_from_loader('statusobs',loader)
mod=importlib.util.module_from_spec(spec)
loader.exec_module(mod)

def sample(seq=0, **kw):
    p=dict(schema='migratable.job.status/1',jobId='J',migrationId='M',state='NEW',sequence=seq,
           startedEpochMs=1000,updatedEpochMs=1000+seq,sourceNodeId='src',sourcePlacementId='lease-1',
           sourceOwnershipEpoch=3,sourceFenced=False,sourceAdmissionReleased=False,
           destinationNodeId='',destinationPlacementId='',destinationOwnershipEpoch=0,
           checkpointId='',handoffMode='QUEUE',handoffId='',destinationResumed=False,
           executionRef='',failureCode='',failureDetail='',resumeState='')
    p.update(kw)
    return p

class StatusTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db=mod.open_db(Path(self.tmp.name)/'s.sqlite3')
        self.addCleanup(self.db.close)
    def put(self,p): return mod.record(self.db,p)
    def rejects(self,p):
        with self.assertRaises(mod.Rejected): self.put(p)
    def test_delayed_snapshot_and_idempotence(self):
        self.assertEqual(self.put(sample()),'OBSERVED')
        self.assertEqual(self.put(sample()),'DUPLICATE')
        self.assertEqual(self.put(sample(2,state='PREPARING')),'OBSERVED')
        self.assertEqual(self.put(sample(1)),'STALE')
        self.assertEqual(mod.audit(self.db)[0],2)
    def test_conflicting_redelivery(self):
        self.put(sample()); self.rejects(sample(state='PREPARING'))
    def test_identity_epoch_and_lease(self):
        self.put(sample()); self.rejects(sample(1,sourceOwnershipEpoch=4))
        self.rejects(sample(1,sourceNodeId='other'))
        self.rejects(sample(1,destinationNodeId='new',destinationPlacementId='lease',destinationOwnershipEpoch=2))
    def test_destination_change(self):
        self.put(sample())
        self.put(sample(1,state='TRANSFERRING',destinationNodeId='new',destinationPlacementId='l2',destinationOwnershipEpoch=4))
        self.rejects(sample(2,state='RUNNING',destinationNodeId='other',destinationPlacementId='l3',destinationOwnershipEpoch=5))
    def test_monotonic_flags(self):
        self.put(sample(sourceFenced=True));self.rejects(sample(1,sourceFenced=False))
    def test_checkpoint_identity(self):
        self.put(sample(checkpointId='cp1'));self.rejects(sample(1,checkpointId='cp2'))
    def test_late_retained_first(self):
        self.put(sample(8,state='PREPARING'))
        self.assertEqual(self.put(sample(2)),'STALE')
    def test_invalid_schema_and_boolean(self):
        for p in [sample(schema='wrong'),sample(sourceFenced=1),sample(sequence=True),sample(state='EXECUTE'),sample(updatedEpochMs=999)]:
            self.rejects(p)
    def test_tamper_fails_closed(self):
        self.put(sample())
        self.db.execute("UPDATE events SET payload=? WHERE row_no=1",('{}',))
        with self.assertRaises(mod.Rejected):mod.audit(self.db)
        self.rejects(sample(1))
    def test_fail_state_terminal(self):
        self.put(sample(state='FAILED'));self.rejects(sample(1,state='RUNNING'))
    def test_unverified_report_and_cli(self):
        self.put(sample())
        r=mod.report(self.db)
        self.assertFalse(r['authenticated']);self.assertFalse(r['purchaseAllowed']);self.assertFalse(r['migrationAllowed'])
        p=Path(self.tmp.name)/'in.json';p.write_text(json.dumps(sample()))
        cli=subprocess.run([sys.executable,str(TOOL),'ingest','--state',self.tmp.name,'--file',str(p)],capture_output=True,text=True)
        self.assertEqual(cli.returncode,0,cli.stderr)
        self.assertEqual(cli.stdout.strip(),'OBSERVED')
        rep=subprocess.run([sys.executable,str(TOOL),'report','--state',self.tmp.name],capture_output=True,text=True)
        self.assertEqual(rep.returncode,0,rep.stderr)
        self.assertFalse(json.loads(rep.stdout)['providerInvoiceReconciled'])

if __name__=='__main__': unittest.main(verbosity=2)
