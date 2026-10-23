"""Parser/output contract tests (no implicit claim of native ooRexx qualification)."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'bin' / 'storage'


class CLITest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / 'state'
        self.rexx = Path(self.tmp.name) / 'fake-rexx'
        self.rexx.write_text('''#!/usr/bin/env python3
import os,sys
op=os.environ['STORAGE_CLI_OP']
if op == 'list':
 print('OBJECT\\tsha256:foo\\tvideo%09name.mp4\\t4096\\tvideo/mp4\\tsha256:foo\\t2\\t2\\tSATISFIED\\t7')
 print('LOCATION\\tfs:ed209c\\ted209c\\t/videos/video.mp4\\tAVAILABLE\\t1\\tSAFE\\tSTABLE\\tAZURE\\tED209C\\tAZURE/ED209C')
 print('LOCATION\\tazure-git\\t\\tgit:branch@c:manifest\\tAVAILABLE\\t1\\tSAFE\\tSTABLE\\tAZURE\\tDEVOPS\\tAZURE/DEVOPS')
 print('OBJECT\\tsha256:bar\\tpart%25test.webm\\t99\\tvideo/webm\\tsha256:bar\\t1\\t0\\tNOT_SET\\t7')
 print('LOCATION\\tfs:ed209b\\ted209b\\t/videos/other.webm\\tOFFLINE\\t0\\tUNKNOWN\\tSTABLE\\tORACLE\\tED209B\\tORACLE/ED209B')
elif op in ('locate','status','register','ensure','materialise'):
 print('OBJECT\\tsha256:foo\\tvideo.mp4\\t4096\\tvideo/mp4\\tsha256:foo\\t1\\t1\\tNOT_SET\\t7')
 print('LOCATION\\tfs:ed209c\\ted209c\\t/videos/video.mp4\\tAVAILABLE\\t1\\tSAFE\\tSTABLE\\tAZURE\\tED209C\\tAZURE/ED209C')
else: sys.exit(3)
print('RESULT\\tOK')
''')
        self.rexx.chmod(0o755)

    def cli(self, *params):
        env = {**os.environ, 'REXX_BIN': str(self.rexx)}
        return subprocess.run([sys.executable, str(CLI), '--state-root', str(self.state), '--node', 'ed209c', *params],
                              capture_output=True, text=True, env=env)

    def test_list_json_all_and_escaping(self):
        p = self.cli('list','--format','json')
        self.assertEqual(0,p.returncode,p.stderr)
        d=json.loads(p.stdout)
        self.assertEqual(2,d['count'])
        self.assertEqual('video\tname.mp4',d['files'][0]['name'])
        self.assertEqual('part%test.webm',d['files'][1]['name'])
        self.assertEqual(2,d['files'][0]['durable_verified_copies'])
        self.assertTrue(d['files'][0]['locations'][0]['verified_at_recording'])

    def test_list_node_filter(self):
        p = self.cli('list','--node','ed209b','--format','json')
        self.assertEqual(0,p.returncode,p.stderr)
        d=json.loads(p.stdout)
        self.assertEqual(1,d['count'])
        self.assertEqual('part%test.webm',d['files'][0]['name'])

    def test_list_provider_filter(self):
        p = self.cli('list','--provider','azure-git','--format','json')
        self.assertEqual(0,p.returncode,p.stderr)
        self.assertEqual(1,json.loads(p.stdout)['count'])

    def test_list_underreplicated(self):
        p=self.cli('list','--underreplicated','--format','json')
        self.assertEqual(0,p.returncode,p.stderr)
        self.assertEqual(1,json.loads(p.stdout)['count'])

    def test_locate_and_status(self):
        for cmd in ['locate','status']:
            p=self.cli(cmd,'sha256:foo','--format','json')
            self.assertEqual(0,p.returncode,p.stderr)
            self.assertEqual('sha256:foo',json.loads(p.stdout)['files'][0]['id'])

    def test_scan_regular_files(self):
        folder=Path(self.tmp.name)/'videos'; folder.mkdir()
        (folder/'one.mp4').write_bytes(b'data')
        (folder/'two.webm').write_bytes(b'data')
        (folder/'symlink.mp4').symlink_to(folder/'one.mp4')
        p=self.cli('scan',str(folder),'--format','json')
        self.assertEqual(0,p.returncode,p.stderr)
        self.assertEqual(2,json.loads(p.stdout)['count'])

    def test_missing_rexx_fails(self):
        self.rexx.unlink()
        p=self.cli('list')
        self.assertNotEqual(0,p.returncode)
        self.assertIn('ooRexx executable unavailable',p.stderr)


if __name__ == '__main__':
    unittest.main()
