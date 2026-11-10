"""Run-scoped exception registration and detection regressions."""
import contextlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import ComputerActions as c
import ComputerExceptions as e


class Dev7Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / 'cfg'
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.config)}, clear=False)
        self.env.start()
        self.addCleanup(self.env.stop)

    def call(self, intent, utterance):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            status = c.execute(intent, utterance)
        return status, buf.getvalue()

    @staticmethod
    def token(text):
        candidates = re.findall(r'Computer confirm ([A-Za-z0-9_-]{32})', text)
        assert candidates, text
        return candidates[-1]

    def enroll(self, name, argv, target='local'):
        code, draft = self.call('JOBS', 'job draft ' + name + ' ' + target + ' -- ' + shlex.join(argv))
        self.assertEqual(code, 3)
        review = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', draft).group(1)
        code, approval = self.call('JOBS', 'job approve ' + review + ' -- ' + shlex.join(argv))
        self.assertEqual(code, 3)
        self.assertEqual(self.call('CONFIRM_ACTION', 'confirm ' + self.token(approval))[0], 0)

    def watch(self, name, rule):
        status, preview = self.call('JOBS', f'job exception register {name} {rule}')
        self.assertEqual(status, 3)
        self.assertIn('JOB_EXCEPTION_PREVIEW', preview)
        status, confirmation = self.call('CONFIRM_ACTION', 'confirm ' + self.token(preview))
        self.assertEqual(status, 0)
        self.assertIn('JOB_EXCEPTION_REGISTERED', confirmation)

    def start(self, name):
        code, preview = self.call('JOBS', 'job start ' + name)
        self.assertEqual(code, 3)
        return self.token(preview)

    def execute(self, token):
        status, output = self.call('CONFIRM_ACTION', 'confirm ' + token)
        run_id = re.search(r'JOB_RESULT_COMMAND=Computer job result (computer-job-[\w-]+)', output).group(1)
        record = json.loads(self.call('JOBS', '--json job result ' + run_id)[1])
        return status, output, record

    def script(self, code):
        path = self.root / 'script.py'
        path.write_text(code)
        return [sys.executable, str(path)]

    def test_runaway_space_crosses_10_meg_then_shrinks(self):
        workspace = self.root / 'workspace'
        workspace.mkdir()
        argv = self.script('''from pathlib import Path
import time
p = Path(%r)/'large.bin'
p.write_bytes(b'x'*11_000_000)
time.sleep(0.40)
p.unlink()
print('work finished normally')
''' % str(workspace))
        self.enroll('grow', argv)
        self.watch('grow', f'runaway_space {workspace} 10 meg')
        status, output, record = self.execute(self.start('grow'))
        self.assertEqual(status, 6, output)
        self.assertIn('EXCEPTION type=runaway_space', output)
        self.assertEqual(record['child_rc'], 0)
        self.assertEqual(record['status'], 'EXITED')
        self.assertEqual(record['exceptions']['count'], 1)
        self.assertEqual(record['exceptions']['raised'][0]['observed']['size_bytes'], 11000000)
        self.assertFalse((workspace / 'large.bin').exists())

    def test_below_threshold_does_not_raise(self):
        workspace = self.root / 'workspace'; workspace.mkdir()
        argv = self.script('''from pathlib import Path
import time
(Path(%r)/'small.bin').write_bytes(b'x'*9_000_000)
time.sleep(0.22)
''' % str(workspace))
        self.enroll('smaller', argv)
        self.watch('smaller', f'runaway_space {workspace} 10 meg')
        status, output, record = self.execute(self.start('smaller'))
        self.assertEqual(status, 0, output)
        self.assertEqual(record['exceptions']['count'], 0)
        self.assertTrue(record['exceptions']['observation_complete'])

    def test_output_error_despite_zero_exit(self):
        self.enroll('errors', self.script("import sys\nprint('ERROR: bad result',file=sys.stderr)\n"))
        self.watch('errors', 'output_contains "ERROR:" stderr')
        status, output, record = self.execute(self.start('errors'))
        self.assertEqual(status, 6)
        self.assertEqual(record['child_rc'], 0)
        self.assertEqual(record['exceptions']['raised'][0]['type'], 'output_contains')
        self.assertEqual(record['exceptions']['raised'][0]['observed']['stream'], 'stderr')

    def test_elapsed_overrun_reports_without_killing(self):
        self.enroll('slow', self.script("import time\ntime.sleep(0.32)\n"))
        self.watch('slow', 'runtime_overrun 0.12 seconds')
        status, output, record = self.execute(self.start('slow'))
        self.assertEqual(status, 6)
        self.assertEqual(record['child_rc'], 0)
        self.assertGreater(record['elapsed_seconds'], 0.12)
        self.assertEqual(record['exceptions']['raised'][0]['type'], 'runtime_overrun')

    def test_new_rule_invalidates_pending_run_confirmation(self):
        self.enroll('pending', ['/bin/true'])
        old = self.start('pending')
        self.watch('pending', 'output_contains "ERROR:"')
        with self.assertRaises(c.ComputerError) as issue:
            self.call('CONFIRM_ACTION', 'confirm ' + old)
        self.assertEqual(issue.exception.status, 4)

    def test_bad_directories_and_remote_local_scope_refused(self):
        self.enroll('test', ['/bin/true'])
        path = self.root / 'real'; path.mkdir()
        (self.root / 'alias').symlink_to(path)
        for rule in (f'runaway_space {self.root}/alias 10 meg',
                     'runaway_space / 10 meg',
                     'runaway_space /definitely/missing 10 meg'):
            with self.assertRaises(c.ComputerError):
                self.call('JOBS', 'job exception register test ' + rule)
        # Prevents accidentally interpreting a remote node's /tmp as the controller's.
        ssh = self.root / 'sshnode.sh'
        ssh.write_text('#!/bin/sh\ncase \"$node\" in\n  ed209b) user=opc;;\nesac\n')
        ssh.chmod(0o700)
        with patch.dict(os.environ, {'COMPUTER_SSHNODE': str(ssh)}):
            self.enroll('remote', ['date', '-u'], 'on ed209b')
            with self.assertRaises(c.ComputerError) as ex:
                self.call('JOBS', f'job exception register remote runaway_space {path} 10 meg')
            self.assertEqual(ex.exception.status, 4)

    def test_rules_list_and_job_revoke(self):
        self.enroll('listme', ['/bin/true'])
        self.watch('listme', 'runtime_overrun 2 seconds')
        self.assertIn('runtime_overrun', self.call('JOBS', 'job exceptions listme')[1])
        self.assertIn('runtime_overrun', self.call('JOBS', 'job show listme')[1])
        code, preview = self.call('JOBS', 'job revoke listme')
        self.assertEqual(code, 3)
        self.assertEqual(self.call('CONFIRM_ACTION', 'confirm '+self.token(preview))[0], 0)
        self.assertNotIn('listme', c.load_state().get('job_exceptions', {}))

    def test_unavailable_space_observation_is_reported_not_clean(self):
        workspace = self.root / 'workspace'; workspace.mkdir()
        self.enroll('lost', self.script('''import shutil, time
shutil.rmtree(%r)
time.sleep(0.22)
''' % str(workspace)))
        self.watch('lost', f'runaway_space {workspace} 10 meg')
        status, output, record = self.execute(self.start('lost'))
        self.assertEqual(status, 6)
        self.assertFalse(record['exceptions']['observation_complete'])
        self.assertEqual(record['exceptions']['raised'][0]['type'], 'measurement_unavailable')

if __name__ == '__main__': unittest.main()
