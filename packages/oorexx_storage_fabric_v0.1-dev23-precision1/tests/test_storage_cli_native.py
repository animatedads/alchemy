"""Integration tests using an actual ooRexx executable and filesystem authority.

Set REXX_BIN to a qualified 5.3.0 interpreter before running. No Azure or
remote XTP hosts are accessed by this test.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'bin' / 'storage'
REXX = os.environ.get('REXX_BIN', 'rexx')

@unittest.skipUnless(shutil.which(REXX), 'ooRexx interpreter not available')
class NativeCLI(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.addCleanup(self.t.cleanup)
        self.base = Path(self.t.name)
        self.state = self.base / 'authority'
        self.video = self.base / 'video.mp4'
        self.video.write_bytes(b'video\x00\x10bytes' * 12)
        self.video_id = 'sha256:' + hashlib.sha256(self.video.read_bytes()).hexdigest()

    def cmd(self, *args, ok=True):
        p = subprocess.run([str(CLI), '--state-root', str(self.state), '--node', 'ed209c', *args],
                           env={**os.environ, 'REXX_BIN': REXX}, cwd=str(self.base), capture_output=True, text=True)
        if ok:
            self.assertEqual(0, p.returncode, f'{p.stdout}\n{p.stderr}')
            return json.loads(p.stdout)['files'] if '--format' in args else p
        self.assertNotEqual(0, p.returncode, f'{p.stdout}\n{p.stderr}')
        return p

    def add(self, virtual='/customers/initech/tps/review.mp4', **overrides):
        args = ['add', str(self.video), '--virtual', virtual, '--format', 'json']
        args += overrides.get('options', [])
        return self.cmd(*args)

    def test_add_locate_find_restart_and_type(self):
        obj = self.add(options=['--description','TPS quarterly review', '--tag','tps',
                               '--tag','audit', '--meta','customer=Initech'])[0]
        self.assertEqual('video/mp4', obj['media_type'])
        self.assertEqual(self.video_id, obj['id'])
        self.assertEqual('TPS quarterly review', obj['description'])
        self.assertEqual('Initech', obj['metadata']['customer'])
        self.assertCountEqual(['tps','audit'],obj['tags'])
        self.assertEqual('/customers/initech/tps/review.mp4',obj['virtual_paths'][0]['path'])
        self.assertEqual(self.video_id, self.cmd('locate','/customers/initech/tps/review.mp4','--format','json')[0]['id'])
        self.assertEqual(1,len(self.cmd('find','quarterly','--format','json')))
        self.assertEqual(1,len(self.cmd('find','Initech','--format','json')))
        self.assertEqual(1,len(self.cmd('list','--tag','tps','--meta','customer=Initech','--format','json')))
        self.assertEqual(0,len(self.cmd('list','--path','/other/','--format','json')))
        # Each CLI invocation reloads its own retained authority checkpoint.
        self.assertGreater(self.cmd('list','--format','json')[0]['catalogue_revision'],0)

    def test_duplicate_paths_and_shared_content(self):
        self.add('/a/1.mp4')
        self.add('/b/2.mp4')
        obj=self.cmd('list','--format','json')
        self.assertEqual(1,len(obj))
        self.assertCountEqual(['/a/1.mp4','/b/2.mp4'],[p['path'] for p in obj[0]['virtual_paths']])
        failed=self.cmd('add',str(self.video),'--virtual','/a/1.mp4',ok=False)
        self.assertIn('VIRTUAL_PATH_EXISTS', failed.stderr)
        failed=self.cmd('remove','/a/1.mp4','--forget','--yes',ok=False)
        self.assertIn('OBJECT_STILL_BOUND',failed.stderr)
        self.assertEqual(2,len(self.cmd('list','--format','json')[0]['virtual_paths']))
        self.cmd('remove','/a/1.mp4','--format','json')
        self.assertEqual(1,len(self.cmd('list','--format','json')[0]['virtual_paths']))
        self.assertEqual(self.video.read_bytes(),b'video\x00\x10bytes'*12)
        self.cmd('remove','/b/2.mp4','--forget','--yes','--format','json')
        self.assertEqual([],self.cmd('list','--format','json'))
        self.assertTrue(self.video.exists())

    def test_annotate_remove_metadata(self):
        self.add('/review.mp4')
        self.cmd('annotate','/review.mp4','--tag','review','--meta','year=2026',
                 '--description','New description','--format','json')
        self.assertEqual('New description',self.cmd('locate','/review.mp4','--format','json')[0]['description'])
        self.assertEqual(1,len(self.cmd('list','--tag','review','--format','json')))
        self.cmd('annotate',self.video_id,'--untag','review','--unset','year','--format','json')
        obj=self.cmd('list','--format','json')[0]
        self.assertEqual([] ,obj['tags'])
        self.assertEqual({},obj['metadata'])

    def test_bind_without_rehashing_and_safe_remove(self):
        self.add('/incoming/video.mp4')
        self.cmd('bind',self.video_id,'--virtual','/catalogue/linked.mp4','--format','json')
        obj=self.cmd('list','--format','json')[0]
        self.assertCountEqual(['/incoming/video.mp4','/catalogue/linked.mp4'],
                              [p['path'] for p in obj['virtual_paths']])
        fail=self.cmd('remove','/incoming/video.mp4','--forget','--yes',ok=False)
        self.assertIn('OBJECT_STILL_BOUND',fail.stderr)
        self.cmd('remove','/incoming/video.mp4','--format','json')
        self.assertEqual(self.video_id,self.cmd('locate','/catalogue/linked.mp4','--format','json')[0]['id'])

    def test_guardrails(self):
        bad=['/a/../b','/a//b','/a/./b','/', 'relative/name']
        for v in bad:
            self.assertIn('virtual path',self.cmd('add',str(self.video),'--virtual',v,ok=False).stderr)
        link=self.base/'link.mp4'
        link.symlink_to(self.video)
        self.assertIn('symlink',self.cmd('add',str(link),'--virtual','/x',ok=False).stderr)
        self.assertIn('requires --yes',self.cmd('remove','/x','--forget',ok=False).stderr)
        self.assertIn('VIRTUAL_PATH_REQUIRED',self.cmd('remove',self.video_id,ok=False).stderr)
        self.assertEqual([],self.cmd('list','--format','json'))

    def test_scan_virtual_directory_and_filter(self):
        folder=self.base/'incoming'; folder.mkdir()
        (folder/'a.mp4').write_bytes(b'a'); (folder/'child').mkdir()
        (folder/'child'/'b.webm').write_bytes(b'b')
        (folder/'fake.mp4').symlink_to(folder/'a.mp4')
        self.cmd('scan',str(folder),'--virtual-root','/raw/2026','--tag','original',
                 '--meta','batch=sep','--format','json')
        a=self.cmd('list','--format','json')
        self.assertEqual(2,len(a))
        self.assertCountEqual(['/raw/2026/a.mp4','/raw/2026/child/b.webm'],
                              [p['path'] for obj in a for p in obj['virtual_paths']])
        self.assertEqual(2,len(self.cmd('list','--tag','original','--format','json')))
        self.assertEqual(1,len(self.cmd('find','child','--format','json')))

    def test_namespaces_and_forget_id(self):
        self.add('/videos/one.mp4')
        self.add('/videos/one.mp4', options=['--namespace','archive'])
        self.assertEqual(2,len(self.cmd('list','--format','json')[0]['virtual_paths']))
        self.assertEqual(1,len(self.cmd('list','--namespace','archive','--format','json')))
        self.cmd('remove','/videos/one.mp4','--namespace','archive','--format','json')
        self.cmd('remove','/videos/one.mp4','--format','json')
        self.cmd('remove',self.video_id,'--forget','--yes','--format','json')
        self.assertEqual([],self.cmd('list','--format','json'))
        self.assertTrue(self.video.is_file())

if __name__=='__main__':
    unittest.main(verbosity=2)
