import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'bin' / 'virtual_ups.py'
spec = importlib.util.spec_from_file_location('virtual_ups_obs', SCRIPT)
ups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ups)


class GuestObservationTests(unittest.TestCase):
    CONSOLE = (b'@HELP\nSJ  0: **** MAILS(4) 21:09:44 ****\n'
               b'SJ  0: [SCHEDULER]:        Waiting for UPS:\n'
               b'SJ  0: **** OPR(3) 21:09:44 ****\n')

    def test_observe_mx_mail_context_not_physical_power(self):
        result = ups.inspect_tops20_console(self.CONSOLE)
        self.assertEqual([3], result['matches']['scheduler_waiting_for_ups_lines'])
        self.assertEqual([2], result['matches']['mails_notification_lines'])
        self.assertFalse(result['electrical_ups_absence_proven'])
        self.assertFalse(result['mail_delivery_failure_proven'])
        self.assertEqual('unknown', result['guest_power_state'])
        self.assertEqual('TOPS20_MX_MAIL_SUBSYSTEM_CONTEXT_POWER_MEANING_UNRESOLVED', result['interpretation'])

    def test_no_false_electrical_ups_signal(self):
        r = ups.inspect_tops20_console(b'UPS battery is missing\n')
        self.assertEqual('NO_MATCHING_SCHEDULER_MESSAGE', r['interpretation'])

    def test_refuse_oversize(self):
        with self.assertRaisesRegex(ValueError, '2MiB'):
            ups.inspect_tops20_console(b'X' * (ups.MAX_CONSOLE_BYTES + 1))

    def test_strict_json_refuses_duplicates_and_nonfinite(self):
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            ups.strict_json_loads('{"a":1,"a":2}')
        with self.assertRaisesRegex(ValueError, 'nonfinite'):
            ups.strict_json_loads('{"v":NaN}')

    def test_cli_read_only_and_no_state_init(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td)/'guest.log'
            path.write_bytes(self.CONSOLE)
            proc = subprocess.run([sys.executable, str(SCRIPT), '--dir', td+'/absent',
                                   'inspect-tops20', '--log', str(path)],
                                  capture_output=True, text=True)
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertIn('mail_delivery_failure_proven', proc.stdout)
            self.assertFalse((Path(td)/'absent').exists())

    def test_event_is_not_synthetic_power_mutation(self):
        r = ups.inspect_tops20_console(self.CONSOLE)
        self.assertFalse(r['synthetic'])
        self.assertNotIn('signals', r)


if __name__ == '__main__':
    unittest.main()
