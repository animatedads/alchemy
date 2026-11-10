"""Self-contained negative/positive fixtures; never contacts live services."""
import csv
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("activation_audit", HERE/"tools/check_activation.py")
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class AuditContractTests(unittest.TestCase):
    def test_ledger_is_valid(self):
        report=mod.validate_ledger(HERE/"docs/SERVICE_CRITICAL_PATH.csv")
        self.assertEqual([x['status'] for x in report],['PASS'])
        self.assertGreaterEqual(int(report[0]['detail'].split()[0]),54)

    def test_private_roles_detect_generic_https_mismatch(self):
        sample="required_units(){\n case \"$ROLE\" in\n noc|public) printf '%s\\n' rasenfalcon-https.service;;\n office) printf '%s\\n' rasenfalcon-https.service;;\n esac\n}"
        policy={'instances':{'noc.rasenfalcon.com':{'service':'rasenfalcon-noc-https.service'},'office.rasenfalcon.com':{'service':'rasenfalcon-office-https.service'}}}
        self.assertEqual(mod.check_unit_names(sample,policy)['status'],'BLOCKED')

    def test_private_roles_accept_distinct_names(self):
        sample="required_units(){\n case \"$ROLE\" in\n noc) printf '%s\\n' rasenfalcon-noc-https.service;;\n office) printf '%s\\n' rasenfalcon-office-https.service;;\n esac\n}"
        policy={'instances':{'noc.rasenfalcon.com':{'service':'rasenfalcon-noc-https.service'},'office.rasenfalcon.com':{'service':'rasenfalcon-office-https.service'}}}
        self.assertEqual(mod.check_unit_names(sample,policy)['status'],'PASS')

    def test_website_digest_detects_edited_qual_file(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td);(p/'website/docs').mkdir(parents=True);(p/'handoff/public_site').mkdir(parents=True)
            relative='docs/QUALIFICATION.md'
            expected=hashlib.sha256(b'approved original').hexdigest()
            (p/'handoff/public_site/github_source.lock.json').write_text(json.dumps({'files_sha256':{relative:expected}}))
            (p/'website/docs/QUALIFICATION.md').write_text('changed')
            result=mod.inspect_website_candidate(p)[0]
            self.assertEqual(result['status'],'BLOCKED')
            self.assertIn(relative,result['detail'])
            (p/'website/docs/QUALIFICATION.md').write_bytes(b'approved original')
            self.assertEqual(mod.inspect_website_candidate(p)[0]['status'],'PASS')

    def test_website_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td); (p/'handoff/public_site').mkdir(parents=True)
            (p/'handoff/public_site/github_source.lock.json').write_text(json.dumps({'files_sha256':{'../../secret':'a'*64}}))
            self.assertEqual(mod.inspect_website_candidate(p)[0]['status'],'INVALID')

    def test_invalid_csv_detected(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'broken.csv';p.write_text('wrong,name\n1,2\n')
            self.assertEqual(mod.validate_ledger(p)[0]['status'],'INVALID')

    def test_audit_only_returns_not_operational(self):
        p=subprocess.run([sys.executable,str(HERE/'tools/check_activation.py'),'--audit-only','--json'],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        report=json.loads(p.stdout)
        self.assertEqual(report['status'],'SOURCE_CHECKS_PASS_NOT_OPERATIONAL')
        self.assertEqual(report['scope'],'READ_ONLY_SOURCE; NO_LIVE_PROBES')

    def test_missing_repo_in_strict_mode_is_denied(self):
        p=subprocess.run([sys.executable,str(HERE/'tools/check_activation.py'),'--repo','/this/is/not/an/alchemy/repo','--strict','--json'],capture_output=True,text=True)
        self.assertEqual(p.returncode,3,p.stdout+p.stderr)
        self.assertEqual(json.loads(p.stdout)['status'],'NOT_READY')

if __name__=='__main__':
    unittest.main()
