#!/usr/bin/env python3
"""Static contract checks only; not an ooRexx runtime test."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class ChangeProjectionBoundary(unittest.TestCase):
    def test_schema(self):
        data = json.loads((ROOT/'contracts/time-change-v0.9.json').read_text())
        self.assertEqual(data['schema'], 'single.time.change/0.1')
        self.assertEqual(data['effect'], 'ADVISORY_ONLY')
        self.assertEqual(data['deliverySemantics'], 'UNPUBLISHED_PROJECTION')

    def test_source_scope(self):
        src = (ROOT/'src/TimeChangePublication.cls').read_text()
        for expected in ['::class \'TimeChangePublication\' public','ruleFromSnapshotId','ruleToSnapshotId','idempotencyKey','UNPUBLISHED_PROJECTION']:
            self.assertIn(expected,src)
        for forbidden in ['::method dispatch','::method enqueue','::method acknowledge','::method send']:
            self.assertNotIn(forbidden,src)

if __name__=='__main__':
    unittest.main()
