import importlib.util,pathlib,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('over',ROOT/'ops/stage_grid_overlay.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
class OverlayTest(unittest.TestCase):
 def make(self,d,handler):
  src=d/'source'
  for part in ('host','guest','scripts'):(src/part).mkdir(parents=True)
  (src/'host/qf-xtp-handler.rex').write_text(handler)
  (src/'guest/init-grid.c').write_text('setenv("QF_XTP_PEERS","/etc/grid/peers.manifest",1);')
  (src/'scripts/build_grid_mn_initramfs.sh').write_text('cp "$HERE/rto2/RexxOSFastCryptoProbe.cls" "$W/root/opt/rexxos/lib/"')
  return src
 def test_additive_preserves_local_fixes(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=pathlib.Path(tmp)
   src=self.make(p,'/* LIVE_FAST_FIX */\nif command[1]="PROBE" then do\n say "OK"\nend\nemitFailure:\n return\nemitResponse:\n return\n::requires "ObjectQueueXTPTransport.cls"\n')
   mod.stage(src,p/'out',ROOT)
   merged=(p/'out/host/qf-xtp-handler.rex').read_text()
   self.assertIn('LIVE_FAST_FIX',merged)
   self.assertIn('RTO2_WORK_RESULT',merged)
   self.assertIn('::requires "RTO2CountJob.cls"',merged)
   self.assertNotIn('RTO2_WORK_RESULT',(src/'host/qf-xtp-handler.rex').read_text())
   with self.assertRaisesRegex(ValueError,'refusing existing'):mod.stage(src,p/'out',ROOT)
 def test_fail_closed_on_divergent_handler(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=pathlib.Path(tmp);src=self.make(p,'totally different')
   with self.assertRaisesRegex(ValueError,'dispatch shape'):mod.stage(src,p/'out',ROOT)
if __name__=='__main__':unittest.main()
