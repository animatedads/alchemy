"""Regression for the General Deployment public preview adapter; never touches hosts."""
import importlib.util
import os
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=pathlib.Path(__file__).resolve().parents[2]
SCRIPT=ROOT/'handoff/deployment/public_preview_staging.py'
def find_provider():
    candidates=[]
    if os.environ.get('RF_GENERAL_DEPLOYMENT_ROOT'):
        candidates.append(pathlib.Path(os.environ['RF_GENERAL_DEPLOYMENT_ROOT']))
    for ancestor in ROOT.parents:
        candidates.extend((ancestor/'packages/oorexx_deployment_v0.1-dev4',
                           ancestor/'oorexx_deployment_v0.1-dev4'))
    for path in candidates:
        if (path/'bin/deploy_tree.sh').is_file() and (path/'VERSION').is_file():
            return path
    return None
PROVIDER=find_provider()
spec=importlib.util.spec_from_file_location('rf_public_staging',SCRIPT)
stage=importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

class PublicPreviewTests(unittest.TestCase):
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_general_deployment_provider_pinned(self):
        self.assertEqual(stage.general_provider(PROVIDER).name,'deploy_tree.sh')
    def test_reject_nonexistent_provider(self):
        with self.assertRaises(ValueError):stage.general_provider(pathlib.Path('/tmp/no-such-provider-rf'))
    def test_disallow_non_temp_target(self):
        for target in ('/', '/opt/rasenfalcon/release', '/etc/systemd/system','/tmp'):
            with self.subTest(target=target), self.assertRaises(ValueError):stage.workspace_path(target)
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_plan_does_not_stage(self):
        with tempfile.TemporaryDirectory(prefix='rf-test-') as root:
            w=pathlib.Path(root)/'review'
            x=stage.run('plan',PROVIDER,stage.workspace_path(str(w)))
            self.assertEqual(x['state'],'SOURCE_ONLY')
            self.assertFalse(w.exists())
            self.assertIn('PLAN generation=',x['plan'])
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_stage_and_reverify(self):
        with tempfile.TemporaryDirectory(prefix='rf-test-') as root:
            w=stage.workspace_path(str(pathlib.Path(root)/'review'))
            x=stage.run('stage',PROVIDER,w)
            self.assertEqual(x['pages'],9)
            self.assertEqual(x['state'],'STAGED_LOCAL_REVIEW')
            self.assertFalse(x['production_release'])
            self.assertTrue((w/'target/current').is_symlink())
            v=stage.run('verify',PROVIDER,w)
            self.assertEqual(x['generation'],v['generation'])
            self.assertEqual(v['files'],15)
            self.assertEqual(x['installed'],'NOT_OBSERVED')
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_cannot_verify_unstaged_target(self):
        with tempfile.TemporaryDirectory(prefix='rf-test-') as root:
            with self.assertRaises(ValueError):stage.run('verify',PROVIDER,pathlib.Path(root)/'review')
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_detect_staged_tampering(self):
        with tempfile.TemporaryDirectory(prefix='rf-test-') as root:
            w=stage.workspace_path(str(pathlib.Path(root)/'review'))
            stage.run('stage',PROVIDER,w)
            (w/'target/current/index.html').write_text('corrupt')
            with self.assertRaisesRegex(ValueError,'differs'):stage.run('verify',PROVIDER,w)
            stage.run('stage',PROVIDER,w) # General Deployment repairs drift
            self.assertEqual(stage.run('verify',PROVIDER,w)['state'],'STAGED_LOCAL_REVIEW')
    @unittest.skipUnless(PROVIDER, "General Deployment v0.1-dev4 not available in this test checkout")
    def test_refuse_failed_source_lock(self):
        with tempfile.TemporaryDirectory(prefix='rf-test-') as root:
            with patch.object(stage,'check_source',side_effect=ValueError('source-lock failed')):
                with self.assertRaisesRegex(ValueError,'source-lock failed'):
                    stage.run('plan',PROVIDER,pathlib.Path(root)/'review')

if __name__=='__main__':unittest.main()
