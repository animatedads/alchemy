"""Production-denial tests for the site-only public installation slice."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'deployment/public_role_slice.py'
spec=importlib.util.spec_from_file_location('public_role_slice', SCRIPT)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

class PublicRoleSliceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.bundle=self.root/'review'/'slice'
        self.bundle.parent.mkdir()

    def make(self):
        report=mod.build(self.bundle)
        self.assertEqual(report['state'],'SOURCE_SLICE_ONLY_NOT_INSTALL_READY')
        return report

    def test_real_candidate_assembles_16_exact_files(self):
        x=self.make()
        self.assertEqual(x['site_files'],15)
        self.assertEqual(x['files_in_manifest'],16)
        self.assertFalse(x['production_release'])
        self.assertEqual(mod.verify(self.bundle)['files'],16)

    def test_double_write_denied_unchanged(self):
        self.make()
        original=(self.bundle/'roles/public/manifest.tsv').read_bytes()
        with self.assertRaises(ValueError): mod.build(self.bundle)
        self.assertEqual(original,(self.bundle/'roles/public/manifest.tsv').read_bytes())

    def test_reject_different_bytes(self):
        self.make()
        with (self.bundle/'roles/public/files/site/index.html').open('ab') as f: f.write(b'bad')
        with self.assertRaisesRegex(ValueError,'bytes differ'): mod.verify(self.bundle)

    def test_reject_missing_file(self):
        self.make()
        (self.bundle/'roles/public/files/site/robots.txt').unlink()
        with self.assertRaises(ValueError): mod.verify(self.bundle)

    def test_reject_extra_file(self):
        self.make()
        (self.bundle/'roles/public/files/site/untracked.js').write_text('x')
        with self.assertRaisesRegex(ValueError,'inventory differs'): mod.verify(self.bundle)

    def test_refuse_synthetic_service_authority(self):
        self.make()
        (self.bundle/'roles/public/services.txt').write_text('rasenfalcon-https.service\n')
        with self.assertRaisesRegex(ValueError,'must not claim'):mod.verify(self.bundle)

    def test_refuse_symlinked_site_file(self):
        self.make()
        target=self.bundle/'roles/public/files/site/robots.txt'
        target.unlink();target.symlink_to('/etc/hosts')
        with self.assertRaises(ValueError):mod.verify(self.bundle)

    def test_refuse_bogus_manifest_destination(self):
        self.make()
        path=self.bundle/'roles/public/manifest.tsv'
        path.write_text(path.read_text().replace('/var/www/rasenfalcon/public/', '/etc/systemd/system/',1))
        with self.assertRaisesRegex(ValueError,'outside site-only scope'):mod.verify(self.bundle)

    def test_refuse_changed_authority_state(self):
        self.make()
        path=self.bundle/'roles/public/public-slice.json'
        v=json.loads(path.read_text());v['installed']=True;path.write_text(json.dumps(v))
        with self.assertRaisesRegex(ValueError,'authority changed'):mod.verify(self.bundle)

    def test_reject_output_inside_source(self):
        with self.assertRaisesRegex(ValueError,'inside source'):mod.safe_new_destination(mod.PACKAGE/'tmp'/'unsafe')

    def test_reject_unsafe_output_path(self):
        with self.assertRaises(ValueError):mod.safe_new_destination(Path('relative'))
        with self.assertRaises(ValueError):mod.safe_new_destination(Path('/tmp'))

    def test_existing_controller_refuses_unowned_service(self):
        self.make()
        ctl=ROOT/'deployment/deploy.sh'
        r=subprocess.run(['bash',str(ctl),'check-release'],env={**__import__('os').environ,
                          'RF_ROLE':'public','RF_RELEASE':str(self.bundle)},capture_output=True,text=True)
        self.assertNotEqual(r.returncode,0)
        self.assertIn('services.txt',r.stderr)

    def test_cli_roundtrip(self):
        r=subprocess.run([sys.executable,str(SCRIPT),'assemble','--output',str(self.bundle)],capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr)
        r=subprocess.run([sys.executable,str(SCRIPT),'verify','--output',str(self.bundle)],capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(json.loads(r.stdout)['files'],16)

if __name__=='__main__':unittest.main()
