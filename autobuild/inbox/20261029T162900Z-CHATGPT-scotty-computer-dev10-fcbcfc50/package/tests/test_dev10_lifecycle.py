"""Dev10: bound POSIX local job process groups to foreground timeout."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import unittest

from test_dev7 import Dev7Tests


@unittest.skipUnless(os.name == 'posix', 'POSIX process-group test')
class Dev10LifecycleTests(Dev7Tests):
    """End-to-end jobs use a private Computer state and registered intent path."""

    def _is_running(self, pid):
        # On Linux, dead children of an unreaping PID 1 may remain as zombies.
        # A zombie is no longer running and cannot execute the job's effects.
        proc_stat = Path(f'/proc/{pid}/stat')
        if proc_stat.exists():
            return proc_stat.read_text().split(') ', 1)[1][0] not in 'ZX'
        try:
            os.kill(pid, 0)
            return True
        except ProcessLookupError:
            return False

    def _run_with_child(self, *, watched=False):
        child_pid_file = self.root / 'child.pid'
        script = self.root / 'spawn.py'
        script.write_text('''import subprocess, sys, time
from pathlib import Path
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
Path(sys.argv[1]).write_text(str(child.pid))
print('ERROR: expected output rule' if len(sys.argv)>2 else 'started', flush=True)
time.sleep(30)
''')
        argv = [sys.executable, str(script), str(child_pid_file)] + (['error'] if watched else [])
        code, preview = self.call('JOBS', 'job draft background local --timeout 1 -- '+ ' '.join(argv))
        self.assertEqual(code, 3)
        import re, shlex
        token = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', preview).group(1)
        code, approval = self.call('JOBS', 'job approve ' + token + ' -- '+ shlex.join(argv))
        self.assertEqual(code,3)
        self.assertEqual(self.call('CONFIRM_ACTION', 'confirm ' + self.token(approval))[0],0)
        if watched:
            self.watch('background', 'output_contains "ERROR:" stdout')
        status, output, meta = self.execute(self.start('background'))
        self.assertTrue(child_pid_file.is_file(), output)
        pid = int(child_pid_file.read_text())
        self.addCleanup(lambda: os.kill(pid, signal.SIGKILL) if self._is_running(pid) else None)
        self.assertEqual(meta['status'], 'TIMEOUT')
        self.assertEqual(meta['child_rc'], 124)
        self.assertTrue(meta['termination']['termination_attempt'])
        self.assertEqual(meta['termination']['termination_scope'], 'posix_process_group')
        self.assertIn('SIGTERM', meta['termination']['signals_sent'])
        self.assertTrue(meta['termination']['direct_child_reaped'])
        self.assertFalse(meta['termination']['detached_or_remote_termination_verified'])
        for _ in range(20):
            if not self._is_running(pid):
                break
            time.sleep(.05)
        self.assertFalse(self._is_running(pid), 'timed out job child still running')
        return status, output, meta

    def test_timeout_kills_local_child_process_group(self):
        status, output, meta = self._run_with_child()
        self.assertEqual(status, 4, output)
        self.assertFalse(meta['exceptions']['count'])

    def test_output_exception_survives_process_group_timeout(self):
        status, output, meta = self._run_with_child(watched=True)
        self.assertEqual(status, 6, output)
        self.assertEqual(meta['exceptions']['raised'][0]['type'], 'output_contains')

    def test_short_job_has_no_termination_attempt(self):
        self.enroll('quick', ['/bin/true'])
        status, output, meta = self.execute(self.start('quick'))
        self.assertEqual(status, 0, output)
        self.assertEqual(meta['status'], 'EXITED')
        self.assertFalse(meta['termination']['termination_attempt'])


if __name__ == '__main__':
    unittest.main()
