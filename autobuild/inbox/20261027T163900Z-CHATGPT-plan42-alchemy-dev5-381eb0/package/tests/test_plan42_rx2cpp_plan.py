#!/usr/bin/env python3
"""Isolated contract tests; do not run rexx, C++, or publish libraries."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ALCHEMY = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ALCHEMY / 'tools'))
import plan42_rx2cpp_plan as native


class NativePlanTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'alchemy'
        self.gen = self.root / 'generated' / 'plan42'
        self.gen.mkdir(parents=True)
        self.old_root, self.old_generated = native.ROOT, native.GENERATED
        native.ROOT, native.GENERATED = self.root, self.gen
        self.addCleanup(self.restore)
        self.src = self.gen / 'hello.rex'
        self.src.write_text("say 'hello'\n", encoding='utf-8')

    def restore(self):
        native.ROOT, native.GENERATED = self.old_root, self.old_generated

    def test_nonexecuting_plan(self):
        out = native.plan(str(self.src), 'standalone')
        self.assertTrue(out['ok']); self.assertEqual(out['status'], 'PROPOSED_ONLY')
        self.assertFalse(out['executed']); self.assertFalse(out['published'])
        self.assertNotIn('proposed_build_argv', out)

    def test_both_modes_are_distinct(self):
        self.assertEqual(native.plan(str(self.src), 'native-package')['status'], 'input-refused')
        other = self.gen / 'worker.cls'
        other.write_text('::class Worker public\n', encoding='utf-8')
        out = native.plan(str(other), 'native-package')
        self.assertEqual(out['mode'], 'native-package')
        self.assertTrue(out['ok'])

    def test_refuse_external_and_symlink(self):
        outside = self.root / 'external.rex'
        outside.write_text("say 'x'\n")
        self.assertFalse(native.plan(str(outside), 'standalone')['ok'])
        sym = self.gen / 'link.rex'
        sym.symlink_to(self.src)
        self.assertFalse(native.plan(str(sym), 'standalone')['ok'])

    def test_guard_stale_hash(self):
        self.assertEqual(native.plan(str(self.src), 'standalone', expected_sha256='bad')['status'], 'source-changed')
        self.assertTrue(native.plan(str(self.src), 'standalone', expected_sha256=native.digest(self.src))['ok'])

    def test_receipt_binding(self):
        r = self.root/'receipt.json'
        record={'schema':'plan42.integration/0.1', 'operation':'compile','ok':True,
                'target':'oorexx','output':str(self.src.relative_to(self.root)),
                'output_sha256':native.digest(self.src), 'executed':False,
                'published':False,'dispatched':False,
                'compatibility':{'status':'native','issues':[]}}
        r.write_text(json.dumps(record))
        ok=native.plan(str(self.src),'standalone',receipt=str(r))
        self.assertTrue(ok['plan42_receipt']['verified'])
        self.assertTrue(ok['plan42_receipt']['plan42_native_compatibility'])
        record['published']=True;r.write_text(json.dumps(record))
        self.assertFalse(native.plan(str(self.src),'standalone',receipt=str(r))['ok'])
        record['published']=False;record['output_sha256']='0'*64;r.write_text(json.dumps(record))
        self.assertFalse(native.plan(str(self.src),'standalone',receipt=str(r))['ok'])

    def test_compiler_checkout_pin_is_not_assumed(self):
        checkout = Path(self.tmp.name)/'rx2cpp'
        checkout.mkdir()
        (checkout/'VERSION').write_text('0.30.18\n')
        (checkout/'build.sh').write_text('#!/bin/bash\n')
        (checkout/'rx2cpp.rex').write_text('say 1\n')
        out=native.plan(str(self.src),'standalone',compiler_root=str(checkout))
        self.assertTrue(out['ok'])
        self.assertEqual(out['status'],'REVIEW_REQUIRED')
        self.assertFalse(out['checkout_pin_verified'])
        self.assertNotIn('proposed_build_argv',out)
        (checkout/'VERSION').write_text('0.30.17\n')
        self.assertEqual(native.plan(str(self.src),'standalone',compiler_root=str(checkout))['status'],'compiler-version-mismatch')

    def test_no_writes_to_source_and_no_execution(self):
        before=native.digest(self.src)
        out=native.plan(str(self.src),'standalone')
        self.assertEqual(before,native.digest(self.src))
        self.assertFalse((self.gen/'native').exists())
        self.assertEqual(out['native_qualification'],'NOT_RUN')

    def test_alchemy_bridge_cli_routing(self):
        # No local rexx or compiler is needed; run adapter with an isolated generated fixture.
        actual = ALCHEMY/'generated'/'plan42'
        actual.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='native-plan-test-',dir=actual) as tmp:
            f=Path(tmp)/'test.rex';f.write_text("say 'hi'\n")
            cmd=[sys.executable,str(ALCHEMY/'tools'/'plan42_bridge.py'),'native-plan',
                 '--source',str(f),'--mode','standalone']
            run=subprocess.run(cmd,text=True,capture_output=True,cwd=ALCHEMY,timeout=10)
            self.assertEqual(run.returncode,0,run.stderr)
            obj=json.loads(run.stdout)
            self.assertEqual(obj['schema'],'plan42.rx2cpp.plan/0.1')
            self.assertTrue(obj['ok'])
            self.assertFalse(obj['executed'])

if __name__ == '__main__':
    unittest.main()
