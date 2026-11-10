#!/usr/bin/env python3
import pathlib, json, unittest, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
class HandoffTests(unittest.TestCase):
    def test_no_retired_target(self):
        for p in ROOT.rglob('*'):
            if p.is_file() and p.suffix in ('.md','.json','.sh','.py','.txt'):
                self.assertNotIn('ed209'+'dec',p.read_text(),str(p))
    def test_all_job_files_present(self):
        o=json.loads((ROOT/'codex/jobs.json').read_text())
        self.assertEqual(len(o['tasks']),9)
        for task in o['tasks']:
            self.assertTrue((ROOT/task['file']).is_file())
            self.assertIn('## Universal Codex execution contract',(ROOT/task['file']).read_text())
    def test_required_targets(self):
        obj=json.loads((ROOT/'deployment/HOSTS.json').read_text())
        self.assertEqual(obj['gateway_targets'], {'tn3270':['ed209zz','ed209z'],'web':['ed209cray','ed209tops']})
        self.assertEqual(obj['canonical']['noc.rasenfalcon.com']['cname'],'london1.rasenfalcon.com')
    def test_deployment_script_syntax(self):
        subprocess.run(['bash','-n',str(ROOT/'deployment/deploy.sh')],check=True)
    def test_no_external_service_installation(self):
        d=(ROOT/'deployment/deploy.sh').read_text().lower()
        for bad in ('apt install postfix', 'apt-get install postfix', 'apt install dovecot', 'apt install slapd','apt install nginx'):
            self.assertNotIn(bad,d)
    def test_release_not_claimed_operational(self):
        self.assertIn('NOT DEPLOYED',(ROOT/'TASKS.md').read_text())
if __name__=='__main__': unittest.main()
