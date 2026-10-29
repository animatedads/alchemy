import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'bin' / 'virtual_ups.py'
spec = importlib.util.spec_from_file_location('virtual_ups', SCRIPT)
ups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ups)


class VirtualUPSTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.store = ups.Store(Path(self.temp.name) / 'state')
        self.params = {'name': 'ed209j-kl10', 'capacity_wh': 100, 'initial_wh': 100,
                       'load_w': 200, 'charge_w': 60, 'low_pct': 20, 'critical_pct': 5}

    def test_mains_and_discharge_thresholds_deterministic(self):
        self.store.init(self.params)
        self.store.mutate('mains', {'present': False})
        res = self.store.mutate('advance', {'seconds': 1800})
        s = res['status']['signals']
        self.assertFalse(s['mains_ok'])
        self.assertTrue(s['battery_empty'])
        self.assertFalse(s['power_available'])
        self.assertEqual(1800, s['logical_seconds'])
        self.assertEqual(['battery_low', 'battery_critical', 'battery_empty'],
                         [x['kind'] for x in res['events']])
        self.assertEqual([1440, 1710, 1800], [x['logical_seconds'] for x in res['events']])
        self.assertEqual(0, res['status']['estimated_battery_runtime_seconds'])

    def test_chunked_tick_equivalence(self):
        self.store.init(self.params)
        self.store.mutate('mains', {'present': False})
        once = self.store.mutate('advance', {'seconds': 1500})
        with tempfile.TemporaryDirectory() as d:
            alt = ups.Store(Path(d))
            alt.init(self.params)
            alt.mutate('mains', {'present': False})
            alt.mutate('advance', {'seconds': 500})
            alt.mutate('advance', {'seconds': 1000})
            other = alt.query('status')
            a = once['status']['state']
            b = other['state']
            a.pop('revision')
            b.pop('revision')
            self.assertEqual(a, b)
            self.assertEqual([x['kind'] for x in once['events']],
                             [x['kind'] for x in alt.query('events') if x['kind'].startswith('battery')])

    def test_recharge_and_signal_generation(self):
        self.store.init(self.params)
        self.store.mutate('mains', {'present': False})
        self.store.mutate('advance', {'seconds': 1800})
        self.store.mutate('mains', {'present': True})
        res = self.store.mutate('advance', {'seconds': 6000})
        self.assertEqual(360000, res['status']['state']['remaining_ws'])
        self.assertTrue(res['status']['signals']['mains_ok'])
        self.assertTrue(res['status']['signals']['power_available'])
        self.assertEqual(['battery_above_critical', 'battery_above_low', 'battery_full'],
                         [x['kind'] for x in res['events']])
        self.assertEqual([2101, 3001, 7800], [x['logical_seconds'] for x in res['events']])

    def test_journal_audit_detects_tamper(self):
        self.store.init(self.params)
        self.store.mutate('mains', {'present': False})
        self.assertTrue(self.store.query('audit')['valid'])
        self.assertEqual(2, self.store.query('audit')['records'])
        path = self.store.journal
        old = path.read_text()
        path.write_text(old.replace('mains_lost', 'mains_idle'))
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.store.query('audit')

    def test_refuses_overwrite(self):
        self.store.init(self.params)
        with self.assertRaisesRegex(ValueError, 'already initialized'):
            self.store.init(self.params)

    def test_invalid_params_and_no_host_effects(self):
        self.store.init(self.params)
        with self.assertRaisesRegex(ValueError, 'watts'):
            self.store.mutate('load', {'watts': 0})
        with self.assertRaisesRegex(ValueError, 'boolean'):
            self.store.mutate('mains', {'present': 1})
        self.assertEqual(1, self.store.query('audit')['records'])
        self.assertFalse(self.store.query('status')['physical_power_authority'])
        self.assertFalse(self.store.query('signals')['guest_attached'])

    def test_jsonrpc_default_read_only_and_notification(self):
        self.store.init(self.params)
        read = ups.jsonrpc({'jsonrpc': '2.0', 'id': 1, 'method': 'ups.status'}, self.store, False)
        self.assertIn('result', read)
        blocked = ups.jsonrpc({'jsonrpc': '2.0', 'id': 2, 'method': 'ups.mains',
                               'params': {'present': False}}, self.store, False)
        self.assertEqual(-32001, blocked['error']['code'])
        self.assertIsNone(ups.jsonrpc({'jsonrpc': '2.0', 'method': 'ups.mains',
                                      'params': {'present': False}}, self.store, True))
        self.assertTrue(self.store.query('signals')['mains_ok'])
        result = ups.jsonrpc({'jsonrpc': '2.0', 'id': 3, 'method': 'ups.mains',
                              'params': {'present': False}}, self.store, True)
        self.assertFalse(result['result']['status']['signals']['mains_ok'])

    def test_cli_consent_and_process(self):
        root = Path(self.temp.name) / 'cli'
        base = [sys.executable, str(SCRIPT), '--dir', str(root)]
        bad = subprocess.run(base + ['init'], capture_output=True, text=True)
        self.assertEqual(2, bad.returncode)
        self.assertFalse((root / 'journal.jsonl').exists())
        ok = subprocess.run(base + ['init', '--simulate'], capture_output=True, text=True)
        self.assertEqual(0, ok.returncode, ok.stderr)
        self.assertEqual(100, int(json.loads(ok.stdout)['state']['remaining_ws'] / 3600))
        advanced = subprocess.run(base + ['advance', '60', '--simulate'], capture_output=True, text=True)
        self.assertEqual(0, advanced.returncode, advanced.stderr)
        self.assertEqual(60, json.loads(advanced.stdout)['status']['state']['logical_seconds'])
        out = subprocess.check_output(base + ['audit'], text=True)
        self.assertTrue(json.loads(out)['valid'])
        rpc = subprocess.run(base + ['rpc-stdio'], input='{"jsonrpc":"2.0","id":1,"method":"ups.status"}\n', capture_output=True, text=True)
        self.assertEqual(0, rpc.returncode)
        self.assertIn('result', json.loads(rpc.stdout))


    def test_private_directory_required(self):
        d = self.store.directory
        d.mkdir()
        os.chmod(d, 0o755)
        with self.assertRaisesRegex(ValueError, 'private'):
            self.store.init(self.params)
        os.chmod(d, 0o700)
        self.store.init(self.params)
        self.assertTrue(self.store.query('audit')['valid'])

    def test_symlink_journal_refused(self):
        self.store.init(self.params)
        original = self.store.journal
        real = original.with_suffix('.bak')
        original.rename(real)
        original.symlink_to(real)
        with self.assertRaises(OSError):
            self.store.query('audit')

    def test_bounded_journal_replay_and_no_overgrowth(self):
        from unittest.mock import patch
        self.store.init(self.params)
        current = self.store.journal.stat().st_size
        with patch.object(ups, 'MAX_JOURNAL_BYTES', current + 8):
            with self.assertRaisesRegex(ValueError, 'journal would exceed'):
                self.store.mutate('mains', {'present': False})
        self.assertEqual(current, self.store.journal.stat().st_size)
        self.assertTrue(self.store.query('audit')['valid'])
        with patch.object(ups, 'MAX_JOURNAL_BYTES', current - 1):
            with self.assertRaisesRegex(ValueError, 'journal too large'):
                self.store.query('audit')

    def test_snapshot_binds_journal_head(self):
        self.store.init(self.params)
        snap = self.store.query('snapshot')
        self.assertEqual(ups.digest(snap['state']), snap['state_sha256'])
        self.assertEqual(self.store.query('audit')['head_sha256'], snap['journal_head_sha256'])


if __name__ == '__main__':
    unittest.main()
