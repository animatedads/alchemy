"""Dev8: output exception evidence under bursty output and bounded scans."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
from ComputerExceptions import RunObserver, OUTPUT_READ_CHUNK_BYTES


class OutputEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.stdout = Path(self.tmp.name) / 'out'
        self.stderr = Path(self.tmp.name) / 'err'
        self.stdout.write_bytes(b'')
        self.stderr.write_bytes(b'')

    def observer(self, needle='ERROR:', stream='stdout'):
        return RunObserver([{'type': 'output_contains', 'needle': needle,
                             'stream': stream}], self.stdout, self.stderr)

    def test_temporary_backlog_clears_without_false_incomplete(self):
        self.stdout.write_bytes(b'a' * (OUTPUT_READ_CHUNK_BYTES * 3 + 123))
        watcher = self.observer()
        watcher.tick()
        self.assertTrue(watcher.complete)
        report = watcher.finish()
        self.assertEqual(report['count'], 0)
        self.assertTrue(report['observation_complete'])
        self.assertEqual(report['output_bytes_examined'], self.stdout.stat().st_size)

    def test_error_after_first_megabyte_detected_at_completion(self):
        self.stdout.write_bytes(b'a' * (OUTPUT_READ_CHUNK_BYTES * 2) + b'ERROR: job failed\n')
        watcher = self.observer()
        watcher.tick()
        report = watcher.finish()
        self.assertEqual(report['count'], 1)
        self.assertEqual(report['raised'][0]['type'], 'output_contains')
        self.assertTrue(report['observation_complete'])

    def test_split_match_across_chunk_boundary(self):
        self.stdout.write_bytes(b'x' * (OUTPUT_READ_CHUNK_BYTES - 3) + b'ERROR: trouble')
        watcher = self.observer()
        watcher.tick()
        report = watcher.finish()
        self.assertEqual(report['count'], 1)
        self.assertTrue(report['observation_complete'])

    def test_scan_budget_exhaustion_is_explicit_not_clean(self):
        from unittest.mock import patch
        import ComputerExceptions as ce
        self.stdout.write_bytes(b'x' * 35)
        with patch.object(ce, 'MAX_OUTPUT_SCAN_BYTES_PER_RULE_STREAM', 20):
            watcher = self.observer()
            report = watcher.finish()
        self.assertFalse(report['observation_complete'])
        self.assertEqual(report['raised'][0]['type'], 'measurement_unavailable')
        self.assertEqual(report['raised'][0]['observed']['bytes_examined'], 20)

    def test_two_streams_and_unrelated_output(self):
        self.stdout.write_text('ordinary stdout')
        self.stderr.write_text('problem: ERROR: bad state')
        report = self.observer(stream='both').finish()
        self.assertEqual(report['count'], 1)
        self.assertEqual(report['raised'][0]['observed']['stream'], 'stderr')


if __name__ == '__main__':
    unittest.main()
