#!/usr/bin/env python3
import json, pathlib, subprocess, sys, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class SuiteTests(unittest.TestCase):
    def test_page_count(self):
        pages = list((ROOT/'website/content/pages').glob('*.json'))
        self.assertEqual(len(pages),9)
    def test_unbundled_dependencies(self):
        for forbidden in ['publisher/dependencies','publisher/reference/rasenfalcon_website_builder_v0.1.zip','publisher/native_store_tmp']:
            self.assertFalse((ROOT/forbidden).exists(),forbidden)
    def test_managed_contract(self):
        x=json.loads((ROOT/'integration.json').read_text())
        self.assertEqual(x['package']['name'],'rasenfalcon_website_suite')
        self.assertEqual(x['schema'],'alchemy.autobuild.integration/0.3')
    def test_regressions(self):
        for cmd in [['python3','tests/test_site.py'],['python3','tests/test_publisher.py'],['python3','tests/test_native_handoff.py']]:
            wd=ROOT/('website' if cmd[1]=='tests/test_site.py' else 'publisher')
            r=subprocess.run(cmd,cwd=wd,capture_output=True,text=True)
            self.assertEqual(r.returncode,0,f'{cmd}: {r.stdout} {r.stderr}')
if __name__=='__main__':unittest.main()
