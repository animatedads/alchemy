"""Dev5: executable, adverse pinned-checkout tests, without native code execution."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import plan42_rx2cpp_plan as p
from plan42_rx2cpp_upstream_audit import audit

class PinnedCheckoutIntegrity(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / 'compiler'
        self.repo.mkdir()
        def git(*args):
            return subprocess.run(['git', '-C', str(self.repo), *args], check=True,
                                  text=True, capture_output=True).stdout.strip()
        self.git = git
        git('init', '-q');git('config', 'user.name','Plan42 tests');git('config','user.email','tests@example.invalid')
        for name in p.REQUIRED_INTERFACES:
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('/* fixture ' + name + ' */\n')
        (self.repo/'oorexx2cpp/VERSION').write_text(p.VERSION+'\n')
        git('add','.');git('commit','-qm','fixture')
        self.saved_pin = p.PIN
        p.PIN = git('rev-parse','HEAD')
        self.addCleanup(setattr,p,'PIN',self.saved_pin)

    def test_all_seven_clean(self):
        report=p.check_checkout_interfaces(self.repo)
        self.assertTrue(report['verified'], report)
        self.assertEqual(len(report['interfaces']),7)

    def test_modified_worktree_rejected_with_unchanged_head(self):
        path=self.repo/p.REQUIRED_INTERFACES[0]
        path.write_text('changed but not committed')
        self.assertEqual(self.git('rev-parse','HEAD'),p.PIN)
        report=p.check_checkout_interfaces(self.repo)
        self.assertFalse(report['verified'])
        self.assertIn('modified-interface:'+p.REQUIRED_INTERFACES[0],report['issues'])

    def test_missing_interface_and_untracked_refused(self):
        path=self.repo/p.REQUIRED_INTERFACES[2]
        path.unlink()
        report=p.check_checkout_interfaces(self.repo)
        self.assertFalse(report['verified'])
        self.assertIn('missing-or-symlink-interface:'+p.REQUIRED_INTERFACES[2],report['issues'])

    def test_symlink_interface_rejected(self):
        path=self.repo/p.REQUIRED_INTERFACES[1]
        path.unlink();path.symlink_to(self.repo/p.REQUIRED_INTERFACES[0])
        self.assertFalse(p.check_checkout_interfaces(self.repo)['verified'])

    def test_native_plan_refuses_modified_checkout(self):
        gen=Path(self.tmp.name)/'workspace'/'generated'/'plan42'
        gen.mkdir(parents=True)
        source=gen/'x.rex';source.write_text("say 1\n")
        saved_root,saved_gen=p.ROOT,p.GENERATED
        p.ROOT,p.GENERATED=gen.parent.parent,gen
        self.addCleanup(setattr,p,'ROOT',saved_root)
        self.addCleanup(setattr,p,'GENERATED',saved_gen)
        path=self.repo/p.REQUIRED_INTERFACES[0]
        path.write_text('corrupted')
        result=p.plan(str(source),'standalone',compiler_root=str(self.repo))
        self.assertEqual(result['status'],'REVIEW_REQUIRED')
        self.assertFalse(result['checkout_pin_verified'])
        self.assertNotIn('proposed_build_argv',result)
        self.assertFalse(result['executed'])

class UpstreamAuditTests(unittest.TestCase):
    def setUp(self):
        self.pin=json.loads((ROOT/'plan42/rx2cpp.upstream.pin.json').read_text())
        self.old={x:'a'*40 for x in self.pin['required_interfaces']}
        self.new=dict(self.old)
        self.new[self.pin['required_interfaces'][0]]='b'*40
        self.snapshot={'repository':self.pin['repository'],'commit':'e'*40,'compiler_version':self.pin['version'],
             'baseline_commit':self.pin['observed_commit'], 'baseline_blobs':self.old,'blobs':self.new}

    def test_change_requires_review_never_promotion(self):
        x=audit(self.pin,self.snapshot)
        self.assertTrue(x['ok']);self.assertEqual(x['status'],'REVIEW_REQUIRED')
        self.assertEqual(len(x['changed_interfaces']),1)
        self.assertFalse(x['pin_changed']);self.assertFalse(x['promoted'])

    def test_missing_interface_refused(self):
        self.snapshot['blobs'].pop(next(iter(self.new)))
        self.assertEqual(audit(self.pin,self.snapshot)['status'],'INTERFACES_INCOMPLETE')

    def test_baseline_mismatch_refused(self):
        self.snapshot['baseline_commit']='0'*40
        self.assertEqual(audit(self.pin,self.snapshot)['status'],'BASELINE_MISMATCH')

    def test_snapshot_does_not_claim_authenticity(self):
        self.assertEqual(audit(self.pin,self.snapshot)['snapshot_authenticity'],'NOT_ATTESTED_BY_THIS_TOOL')

if __name__ == '__main__': unittest.main()
