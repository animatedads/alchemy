"""R-11: diagnostics stay typed without exposing untrusted reply data."""
import pathlib
import sys
import unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"ops"))
from classify_native_failure import classify

class R11(unittest.TestCase):
    def test_known_class(self):
        self.assertEqual(classify("RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE"),"RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE")
        self.assertEqual(classify("RTO2_MI_RESPONSE_NOT_QFXTP bytes=179 PRIVATE=secret"),"RTO2_MI_RESPONSE_NOT_QFXTP")
    def test_unknown_private_payload(self):
        self.assertEqual(classify("private-token=secret\nOTHER_FAULT"),"NATIVE_EXECUTION_FAILURE")
    def test_exact_prefix(self):
        self.assertEqual(classify("WARN RTO2_RESULT_NOT_COMMITTED"),"NATIVE_EXECUTION_FAILURE")
    def test_wrapper_preserves_exit_code(self):
        wrapper=(ROOT/"bin/mu_controller_run.sh").read_text()
        self.assertIn("native_rc=$?",wrapper)
        self.assertIn('exit "$native_rc"',wrapper)
        self.assertIn("ops/classify_native_failure.py",wrapper)
        self.assertNotIn("native XTP RTO2 execution failed for $NODE",wrapper)
if __name__=="__main__":unittest.main()
