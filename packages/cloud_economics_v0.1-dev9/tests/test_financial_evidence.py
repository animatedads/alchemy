#!/usr/bin/env python3
"""Native stdlib financial observation boundary — no real provider APIs used."""
import hashlib
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = ROOT / 'tools/financial-evidence'
SHA = hashlib.sha256(b'fixture-source-evidence').hexdigest()
SCOPE = dict(schema='cloud.economics.financial-evidence/0.1', case_id='case-64G',
             job_id='job-64G', lease_id='lease-7', start=1794000000, end=1794003600,
             currency='USD', source_system='fixture', source_sha256=SHA,
             source_class='FIXTURE', observed_at=1794004000)

def item(kind, ident, **extra):
    r = dict(SCOPE, kind=kind, id=ident, source_ref='source-'+ident)
    r.update(extra)
    return r

BASE = item('BASELINE','baseline-1',amount='1.000000',baseline_policy='on-demand-unmanaged',like_for_like=True,expected_charge_lines=2)
USAGE = item('USAGE','usage-1',quantity='2.000000',unit='CPU_S',resource='cpu-compute')
CHARGE1 = item('CHARGE','charge-1',amount='0.280000',invoice_id='invoice-1',line_id='line-a',charge_status='INVOICED')
CHARGE2 = item('CHARGE','charge-2',amount='0.300000',invoice_id='invoice-1',line_id='line-b',charge_status='INVOICED')

class FinancialEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='cloud-financial-test-')
        self.addCleanup(self.tmp.cleanup)
        self.state = pathlib.Path(self.tmp.name)/'state'
        self.input = pathlib.Path(self.tmp.name)/'input.jsonl'
    def call(self, command, records=None, ok=True, *other):
        if records is not None:
            self.input.write_text(''.join(json.dumps(x,sort_keys=True)+'\n' for x in records))
        args=[sys.executable,str(CLI),command,'--state',str(self.state)]
        if records is not None:
            args.extend(['--file',str(self.input)])
        args.extend(other)
        p = subprocess.run(args,capture_output=True,text=True)
        if ok:
            self.assertEqual(p.returncode,0,(p.stdout,p.stderr))
            return json.loads(p.stdout)
        self.assertNotEqual(p.returncode,0,p.stdout)
        self.assertIn('FINANCIAL_EVIDENCE_REJECTED',p.stderr)
        return p.stderr
    def test_empty_audit_is_not_financial_authority(self):
        r=self.call('audit')
        self.assertEqual(r['events'],0)
        self.assertEqual(r['local_journal'],'CONSISTENT_UNAUTHENTICATED')
    def test_complete_report_is_not_realized_savings(self):
        self.call('ingest',[BASE,USAGE,CHARGE1,CHARGE2])
        r=self.call('report')['cases'][0]
        self.assertEqual(r['status'],'UNVERIFIED_COUNTERFACTUAL_DELTA')
        self.assertEqual(r['reported_delta_not_realized'],'0.420000')
        self.assertIsNone(r['realized_savings'])
        self.assertFalse(r['external_source_verified'])
    def test_replay_idempotent(self):
        self.call('ingest',[BASE,USAGE,CHARGE1,CHARGE2])
        r=self.call('ingest',[BASE,USAGE,CHARGE1,CHARGE2])
        self.assertEqual((r['accepted'],r['idempotent_replays']),(0,4))
        self.assertEqual(self.call('audit')['events'],4)
    def test_event_id_equivocation_fails_closed(self):
        self.call('ingest',[BASE]); x=dict(BASE,amount='99.000000')
        self.call('ingest',[x],False)
        self.assertEqual(self.call('audit')['events'],1)
    def test_invoice_line_double_counting_fails_closed(self):
        self.call('ingest',[CHARGE1]); x=dict(CHARGE1,id='charge-new',source_ref='source-new')
        self.call('ingest',[x],False)
        self.assertEqual(self.call('audit')['events'],1)
    def test_transaction_all_or_nothing(self):
        x=dict(BASE,amount='NaN')
        self.call('ingest',[USAGE,x],False)
        self.assertEqual(self.call('audit')['events'],0)
    def test_scope_drift_cannot_mix_lease(self):
        self.call('ingest',[BASE]); x=dict(CHARGE1,lease_id='other-lease')
        self.call('ingest',[x],False)
    def test_scope_drift_cannot_mix_currency(self):
        self.call('ingest',[BASE]); x=dict(CHARGE1,currency='GBP')
        self.call('ingest',[x],False)
    def test_incomplete_never_reports_delta(self):
        self.call('ingest',[BASE,CHARGE1,USAGE]); r=self.call('report')['cases'][0]
        self.assertEqual(r['status'],'INCOMPLETE_EVIDENCE')
        self.assertIsNone(r['reported_delta_not_realized'])
    def test_estimated_charge_never_reports_delta(self):
        x=dict(CHARGE2,charge_status='ESTIMATED')
        self.call('ingest',[BASE,USAGE,CHARGE1,x]); r=self.call('report')['cases'][0]
        self.assertEqual(r['status'],'INCOMPLETE_EVIDENCE')
    def test_without_usage_never_reports_delta(self):
        self.call('ingest',[BASE,CHARGE1,CHARGE2]); r=self.call('report')['cases'][0]
        self.assertEqual(r['status'],'INCOMPLETE_EVIDENCE')
    def test_hash_tampering_detected(self):
        self.call('ingest',[BASE,USAGE])
        db=sqlite3.connect(str(self.state/'financial-evidence.sqlite3'))
        db.execute('UPDATE evidence SET body=? WHERE event_id=?',('{}','usage-1'))
        db.commit();db.close()
        self.call('audit',ok=False)
        self.call('report',ok=False)
    def test_duplicate_baseline_fails_closed(self):
        self.call('ingest',[BASE]); x=dict(BASE,id='baseline-2',source_ref='other-source')
        self.call('ingest',[x],False)
    def test_no_claimed_external_verification_accepted(self):
        x=dict(CHARGE1,source_class='EXTERNAL_VERIFIED')
        self.call('ingest',[x],False)
    def test_json_duplicate_key_rejected(self):
        self.input.write_text('{'+'"schema":"a","schema":"b"'+'}\n')
        p=subprocess.run([sys.executable,str(CLI),'ingest','--state',str(self.state),'--file',str(self.input)],capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)
    def test_unknown_attribute_rejected(self):
        x=dict(BASE,aws_key='should-not-be-here')
        self.call('ingest',[x],False)
    def test_observer_does_not_write_paper_ledger(self):
        self.call('ingest',[BASE,CHARGE1]);
        self.assertFalse((self.state/'accounts.tsv').exists())
        self.assertFalse((self.state/'decisions.tsv').exists())

if __name__ == '__main__':
    unittest.main(verbosity=2)
