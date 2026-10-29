"""Adversarial source, receipt and compiler worktree tests for dev6."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import plan42_rx2cpp_plan as p


class WorkspaceGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'workspace'
        self.gen = self.root / 'generated' / 'plan42'
        self.gen.mkdir(parents=True)
        self.source = self.gen / 'worker.rex'
        self.source.write_text("say 'hello'\n", encoding='utf-8')
        self.before = (p.ROOT, p.GENERATED)
        p.ROOT, p.GENERATED = self.root, self.gen
        self.addCleanup(self.restore)

    def restore(self):
        p.ROOT, p.GENERATED = self.before

    def test_direct_source_still_allowed(self):
        self.assertTrue(p.plan(str(self.source), 'standalone')['ok'])

    def test_linked_parent_inside_generated_is_refused(self):
        (self.gen / 'real').mkdir()
        nested = self.gen / 'real' / 'ok.rex'
        nested.write_text("say 1\n")
        (self.gen / 'alias').symlink_to(self.gen / 'real', target_is_directory=True)
        self.assertEqual(p.plan(str(self.gen/'alias'/'ok.rex'), 'standalone')['status'], 'input-refused')
        self.assertTrue(p.plan(str(nested), 'standalone')['ok'])

    def test_linked_generated_parent_is_refused(self):
        (self.root/'alias').symlink_to(self.gen, target_is_directory=True)
        self.assertEqual(p.plan(str(self.root/'alias'/'worker.rex'), 'standalone')['status'], 'input-refused')

    def test_receipt_symlink_parent_is_refused(self):
        (self.root / 'reports').mkdir()
        receipt = self.root / 'reports' / 'receipt.json'
        receipt.write_text(json.dumps({
            'schema': 'plan42.integration/0.1', 'operation':'compile',
            'ok':True, 'target':'oorexx', 'output':str(self.source.relative_to(self.root)),
            'output_sha256':p.digest(self.source), 'compatibility':{'status':'native'}}))
        (self.root/'alias-reports').symlink_to(self.root/'reports',target_is_directory=True)
        ok = p.plan(str(self.source),'standalone',receipt=str(receipt))
        self.assertTrue(ok['plan42_receipt']['verified'])
        bad = p.plan(str(self.source),'standalone',receipt=str(self.root/'alias-reports'/'receipt.json'))
        self.assertEqual(bad['status'],'input-refused')

    def test_parent_traversal_refused(self):
        self.assertEqual(p.plan(str(self.gen/'nested'/'..'/'worker.rex'),'standalone')['status'],'input-refused')


class CompilerTreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)/'oorexx'
        self.repo.mkdir()
        def git(*cmd):
            return subprocess.run(['git','-C',str(self.repo),*cmd], check=True,
                                  text=True,capture_output=True).stdout.strip()
        self.git = git
        git('init','-q');git('config','user.name','Guard');git('config','user.email','guard@example.invalid')
        for path in p.REQUIRED_INTERFACES:
            out=self.repo/path;out.parent.mkdir(parents=True,exist_ok=True)
            out.write_text('fixture '+path+'\n')
        extra = self.repo/'oorexx2cpp/rules/StmtIf.cls'
        extra.parent.mkdir(exist_ok=True)
        extra.write_text('original rules\n')
        git('add','.');git('commit','-qm','fixture')
        self.extra=extra

    def test_clean_tree_qualifies(self):
        self.assertTrue(p.check_checkout_interfaces(self.repo)['verified'])

    def test_modified_non_interface_rule_denied(self):
        self.extra.write_text('malicious replacement\n')
        out=p.check_checkout_interfaces(self.repo)
        self.assertFalse(out['verified'])
        self.assertIn('dirty-compiler-tree',out['issues'])
        self.assertTrue(all(x['unchanged'] for x in out['interfaces']))

    def test_untracked_compiler_helper_denied(self):
        (self.repo/'oorexx2cpp/native/arbitrary.rex').write_text('unsafe')
        out=p.check_checkout_interfaces(self.repo)
        self.assertFalse(out['verified'])
        self.assertIn('dirty-compiler-tree',out['issues'])

    def test_unrelated_repo_docs_do_not_block(self):
        (self.repo/'unrelated.txt').write_text('notes')
        self.assertTrue(p.check_checkout_interfaces(self.repo)['verified'])

if __name__ == '__main__':
    unittest.main()
