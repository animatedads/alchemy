#!/usr/bin/env python3
"""Model format and receipt boundary regression: fabricated data, NOT live ooRexx."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import plan42_rx2cpp_inventory as inv
import plan42_rx2cpp_plan as planner


def h(s):
    return s.encode('utf-8').hex().upper()


def row(kind, owner='', selector='', visibility='PUBLIC', flags='', body=''):
    return '\t'.join((kind, h(owner), h(selector), h(visibility), h(flags), h(body)))


class InventoryTests(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.root = Path(d.name) / 'alchemy'
        self.gen = self.root / 'generated' / 'plan42'
        self.gen.mkdir(parents=True)
        self.source = self.gen / 'agent.cls'
        self.source.write_bytes(b'::class Agent public\n::method run\n  return 1\n')
        self.model = self.root / 'agent.object-map.tsv'
        self.oldroot, self.oldgen = planner.ROOT, planner.GENERATED
        planner.ROOT, planner.GENERATED = self.root, self.gen
        self.addCleanup(self.restore)
        self.reset()

    def restore(self):
        planner.ROOT, planner.GENERATED = self.oldroot, self.oldgen

    def reset(self, extra=None, original=None):
        lines = ['RX2CPP_OBJECT_MODEL/0.1',
                 'PACKAGE\t' + h(str(original or self.source)) + '\t9\t0\tSCIENTIFIC\tPROLOG\t0',
                 row('CLASS', selector='Agent'),
                 row('METHOD', owner='Agent', selector='RUN', visibility='PRIVATE', flags='GUARDED,', body='return 1')]
        lines.extend(extra or [])
        self.model.write_text('\n'.join(lines)+'\n', encoding='ascii')

    def result(self):
        return inv.load_inventory(str(self.source), str(self.model), 'native-package')

    def test_import_preserves_private_and_exact_body(self):
        obj = self.result()
        self.assertTrue(obj['ok'], obj)
        self.assertEqual(obj['status'], 'IMPORTED_UNATTESTED')
        self.assertEqual(obj['unit_count'], 2)
        unit = obj['units'][1]
        self.assertEqual(unit['visibility'], 'PRIVATE')
        self.assertEqual(unit['flags'], ['GUARDED'])
        self.assertEqual(bytes.fromhex(unit['source_hex']), b'return 1')
        self.assertEqual(unit['source_sha256'], hashlib.sha256(b'return 1').hexdigest())
        self.assertFalse(obj['export_authenticity_verified'])
        self.assertEqual(obj['source_to_model_semantic_equivalence'], 'UNVERIFIED')
        self.assertFalse(obj['executed'])

    def test_class_init_alias_scope(self):
        self.reset([row('CLASS_METHOD', 'Agent', 'INIT', 'PRIVATE', 'INSPECTION_ALIAS,', 'return .nil')])
        obj=self.result()
        self.assertTrue(obj['ok'], obj)
        self.assertEqual(obj['units'][-1]['flags'], ['INSPECTION_ALIAS'])
        self.assertEqual(obj['units'][-1]['scope'], 'METHOD')

    def test_utf8_and_multiline_hex(self):
        self.reset([row('ROUTINE', selector='ÉTAT', body="say 'réussi'\nreturn .nil")])
        obj = self.result()
        self.assertTrue(obj['ok'], obj)
        self.assertEqual(obj['units'][-1]['selector'], 'ÉTAT')
        self.assertEqual(bytes.fromhex(obj['units'][-1]['source_hex']).decode('utf-8'), "say 'réussi'\nreturn .nil")

    def test_missing_exact_schema(self):
        self.model.write_text(self.model.read_text().replace('RX2CPP_OBJECT_MODEL/0.1','v0.2'))
        self.assertFalse(self.result()['ok'])

    def test_wrong_source_binding(self):
        self.reset(original=self.gen/'other.cls')
        self.assertIn('differs', self.result()['reason'])

    def test_model_symlink_refused(self):
        link = self.root/'link.tsv'
        link.symlink_to(self.model)
        self.assertFalse(inv.load_inventory(str(self.source), str(link),'native-package')['ok'])

    def test_outside_model_refused(self):
        outside = self.root.parent/'outside.tsv'
        outside.write_bytes(self.model.read_bytes())
        self.assertFalse(inv.load_inventory(str(self.source),str(outside),'native-package')['ok'])

    def test_unknown_record_kind_refused(self):
        self.reset([row('edge',selector='X')])
        self.assertFalse(self.result()['ok'])

    def test_undefined_owner_refused(self):
        self.reset([row('METHOD', owner='NotAgent',selector='X',body='return 1')])
        self.assertFalse(self.result()['ok'])

    def test_duplicate_unit_refused(self):
        self.reset([row('METHOD',owner='Agent',selector='RUN',body='return 2')])
        self.assertFalse(self.result()['ok'])

    def test_invalid_flags_refused(self):
        self.reset([row('METHOD',owner='Agent',selector='X', flags='SUPERUSER,')])
        self.assertFalse(self.result()['ok'])

    def test_bad_hex_refused(self):
        self.model.write_bytes(self.model.read_bytes().replace(b'72657475726E2031',b'FFZ'))
        self.assertFalse(self.result()['ok'])

    def test_no_build_side_effects(self):
        before = planner.digest(self.source)
        obj=self.result()
        self.assertEqual(before,planner.digest(self.source))
        self.assertFalse((self.gen/'native').exists())
        self.assertFalse(obj['published'])

    def test_prologue_and_noprolog(self):
        self.reset([row('PROLOGUE',selector='MAIN',visibility='PACKAGE',body='say 2')])
        obj=self.result()
        self.assertTrue(obj['ok'],obj)
        self.assertEqual(obj['counts']['PROLOGUE'],1)
        self.model.write_text(self.model.read_text().replace('SCIENTIFIC\tPROLOG\t','SCIENTIFIC\tNOPROLOG\t'))
        self.assertEqual(self.result()['package']['prolog'],'NOPROLOG')

    def test_native_plan_links_code_unit_scope_without_execution(self):
        result = planner.plan(str(self.source), 'native-package', model=str(self.model))
        self.assertTrue(result['ok'],result)
        self.assertEqual(result['status'], 'PROPOSED_ONLY')
        units = result['inspector_inventory']['units']
        self.assertEqual([(x['kind'], x['scope']) for x in units],
                         [('CLASS', 'CLASS'), ('METHOD', 'METHOD')])
        self.assertNotIn('source_hex', units[1])
        self.assertIn('pinned-interpreter-object-model-capture-and-verification', result['requires'])
        self.assertFalse(result['published'])

    def test_native_plan_rejects_stale_inspector_source_binding(self):
        self.reset(original=self.gen/'not-the-source.cls')
        result=planner.plan(str(self.source),'native-package',model=str(self.model))
        self.assertFalse(result['ok'])
        self.assertEqual(result['status'],'inventory-refused')

    def test_wrong_mode_cannot_import(self):
        self.assertFalse(inv.load_inventory(str(self.source),str(self.model),'standalone')['ok'])

    def test_cli_alchemy_route(self):
        actual = ROOT/'generated'/'plan42'
        actual.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='inventory-test-',dir=actual) as td:
            t=Path(td)
            f=t/'check.cls'; f.write_text('::class A public\n')
            m=ROOT/'reports'/'inventory_cli_fixture.tsv'
            m.parent.mkdir(parents=True,exist_ok=True)
            try:
                m.write_text('\n'.join(['RX2CPP_OBJECT_MODEL/0.1',
                    'PACKAGE\t'+h(str(f))+'\t9\t0\tSCIENTIFIC\tPROLOG\t0',
                    row('CLASS', selector='A')])+'\n')
                p=subprocess.run([sys.executable,str(ROOT/'tools'/'plan42_bridge.py'),
                                  'native-inventory','--source',str(f),'--model',str(m),
                                  '--mode','native-package'],cwd=ROOT,capture_output=True,text=True,timeout=10)
                self.assertEqual(p.returncode,0,p.stdout+'\n'+p.stderr)
                obj=json.loads(p.stdout)
                self.assertTrue(obj['ok']);self.assertEqual(obj['unit_count'],1)
            finally:
                m.unlink(missing_ok=True)


if __name__=='__main__': unittest.main()
