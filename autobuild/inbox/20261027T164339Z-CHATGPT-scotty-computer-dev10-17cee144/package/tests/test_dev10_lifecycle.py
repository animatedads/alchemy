"""Dev10 regression: timeout ends the foreground local job's process group."""
import contextlib
import io
import os
from pathlib import Path
import re
import shlex
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import ComputerActions as computer


@unittest.skipUnless(os.name == 'posix', 'POSIX process-group semantics')
class ProcessGroupTimeout(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.config = self.root / 'config'
        env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.config)})
        env.start()
        self.addCleanup(env.stop)

    def invoke(self, intent, text):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = computer.execute(intent, text)
        return code, output.getvalue()

    def token(self, output, prefix):
        match = re.search(re.escape(prefix) + r'([A-Za-z0-9_-]{32})', output)
        self.assertIsNotNone(match, output)
        return match.group(1)

    def create_job(self, name):
        child_marker = self.root / (name + '.escaped')
        script = self.root / (name + '.py')
        program = ("import time, pathlib; time.sleep(1.8); "
                   "pathlib.Path(" + repr(str(child_marker)) + ").write_text('escaped')")
        script.write_text("import subprocess, sys, time\n"
                          "subprocess.Popen([sys.executable, '-c', " + repr(program) + "])\n"
                          "time.sleep(8)\n")
        args = [sys.executable, str(script)]
        draft = f'job draft {name} local --timeout 1 -- ' + shlex.join(args)
        rc, output = self.invoke('JOBS', draft)
        self.assertEqual(rc, 3, output)
        review = self.token(output, 'job approve ')
        rc, output = self.invoke('JOBS', f'job approve {review} -- ' + shlex.join(args))
        self.assertEqual(rc, 3, output)
        confirm = self.token(output, 'NOT REGISTERED until: Computer confirm ')
        self.assertEqual(self.invoke('CONFIRM_ACTION', 'confirm ' + confirm)[0], 0)
        return child_marker

    def run_and_verify(self, name, has_exception):
        marker = self.create_job(name)
        if has_exception:
            rc, output = self.invoke('JOBS', f'job exception register {name} output_contains ERROR: both')
            self.assertEqual(rc, 3, output)
            token = self.token(output, 'Computer confirm ')
            self.assertEqual(self.invoke('CONFIRM_ACTION', 'confirm ' + token)[0], 0)
        rc, preview = self.invoke('JOBS', 'job run ' + name)
        self.assertEqual(rc, 3, preview)
        run_token = self.token(preview, 'CONFIRM_RUN=Computer confirm ')
        rc, output = self.invoke('CONFIRM_ACTION', 'confirm ' + run_token)
        self.assertEqual(rc, 4, output + '\n' + Path(re.search(r'RECEIPT stdout=\S+ stderr=(\S+)',output).group(1)).read_text() if 'RECEIPT stdout=' in output else output)
        self.assertIn('RESULT status=TIMEOUT rc=124', output)
        self.assertIn('TERMINATION_ATTEMPT=posix_process_group_sigkill', output)
        self.assertIn('SCOPE=local_process_group_only', output)
        self.assertIn('EXCEPTION_REPORT count=0 complete=true', output)
        # The grandchild would have produced this file after ~1.8s without a
        # process-group signal. The leader was killed at ~1s.
        time.sleep(1.15)
        self.assertFalse(marker.exists(), 'timed-out job left a surviving subprocess')
        # The receipt must preserve the factual termination-attempt boundary.
        run_id = re.search(r'JOB_RESULT_COMMAND=Computer job result (\S+)', output).group(1)
        rc, result = self.invoke('JOBS', 'job result ' + run_id)
        self.assertEqual(rc, 0, result)
        self.assertIn('posix_process_group_sigkill', result)

    def test_timeout_stops_process_group_without_exceptions(self):
        self.run_and_verify('plain', False)

    def test_timeout_stops_process_group_with_registered_exception(self):
        self.run_and_verify('observed', True)


if __name__ == '__main__':
    unittest.main()
