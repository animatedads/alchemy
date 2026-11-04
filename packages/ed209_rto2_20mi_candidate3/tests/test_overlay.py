import importlib.util
import pathlib
import sys
import tempfile
import unittest
BASE=pathlib.Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('over',BASE/'ops/stage_grid_overlay.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
class PatchTests(unittest.TestCase):
    def test_retains_existing_handler_local_fixes(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=pathlib.Path(tmp);source=p/'source';target=p/'target'
            for sub in ('host','guest','scripts'):(source/sub).mkdir(parents=True)
            (source/'host/qf-xtp-handler.rex').write_text('/* LIVE_FAST_PATCH_SENTINEL */\nif command[1]="PROBE" then do\n  say "noop"\nend\nemitFailure:\n return\nemitResponse:\n return\n::requires "ObjectQueueXTPTransport.cls"\n')
            (source/'guest/init-grid.c').write_text('setenv("QF_XTP_PEERS","/etc/grid/peers.manifest",1);')
            (source/'scripts/build_grid_mn_initramfs.sh').write_text('cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$W/root/opt/rexxos/lib/"')
            mod.stage(source,target,BASE)
            h=(target/'host/qf-xtp-handler.rex').read_text()
            self.assertIn('LIVE_FAST_PATCH_SENTINEL',h)
            self.assertIn('RTO2_WORK_RESULT',h)
            self.assertIn('::requires "RTO2CountJob.cls"',h)
            self.assertIn('::requires "AlchemyRTO.cls"',h)
            self.assertEqual('/* LIVE_FAST_PATCH_SENTINEL */', (source/'host/qf-xtp-handler.rex').read_text().splitlines()[0])
            with self.assertRaisesRegex(ValueError,'refusing existing'):mod.stage(source,target,BASE)
    def test_rejects_unreconcilable_handler(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=pathlib.Path(tmp);s=p/'s'
            for sub in ('host','guest','scripts'):(s/sub).mkdir(parents=True)
            (s/'host/qf-xtp-handler.rex').write_text('custom transport')
            (s/'guest/init-grid.c').write_text('x')
            (s/'scripts/build_grid_mn_initramfs.sh').write_text('x')
            with self.assertRaisesRegex(ValueError,'dispatch shape'):mod.stage(s,p/'out',BASE)
if __name__=='__main__':unittest.main()
