"""Reviewers' Claude Code hook and closed-pipe acceptance cases."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / '.claude/hooks/computer_approval.py'

class HookAndPipeTests(unittest.TestCase):
    def hook(self, command):
        input_doc = {'tool_name': 'Bash', 'tool_input': {'command': command}}
        run = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(input_doc),
                             text=True, capture_output=True, timeout=8)
        self.assertEqual(run.returncode, 0, run.stderr)
        return json.loads(run.stdout)['hookSpecificOutput']['permissionDecision'] if run.stdout else None

    def test_hook_asks_for_confirmation_and_policy_changes(self):
        for command in ("Computer 'confirm abc'", "rexx ./Computer 'confirm abc'",
                        "./Computer job approve XYZ -- /bin/date -u",
                        "Computer 'job exception register grow runaway_space /tmp/work 10 meg'",
                        "bash -lc \"Computer job policy disk repeat-readonly\"",
                        "Computer 'job revoke disk'"):
            with self.subTest(command=command):
                self.assertEqual(self.hook(command), 'ask')

    def test_hook_rejects_raw_backend_but_allows_read_queries(self):
        self.assertEqual(self.hook('python3 src/ComputerActions.py --intent CONFIRM_ACTION --hex 4142'), 'deny')
        for command in ("Computer help", "Computer 'job result computer-job-test-abcd'",
                        "rexx ./Computer 'job run disk'", "Computer 'job exceptions disk'"):
            self.assertIsNone(self.hook(command))

    def test_broken_pipe_is_not_internal_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            large=Path(tmp)/'large.md'
            large.write_text('x'*800000, encoding='utf8')
            # Force an early EOF from the downstream reader. Python must not
            # print COMPUTER_ERROR rc=5 merely because the pipe closed.
            cmd=['bash','-o','pipefail','-c',
                 '"$PY" "$ACTION" --intent READ_DOCUMENT --hex "$HEX" | head -c 1 >/dev/null']
            utterance='read document '+str(large)
            env={**os.environ,'PY':sys.executable,'ACTION':str(ROOT/'src/ComputerActions.py'),
                 'HEX':utterance.encode().hex().upper()}
            run=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=20)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertNotIn('BrokenPipeError',run.stderr)
            self.assertNotIn('COMPUTER_ERROR rc=5',run.stderr)

if __name__ == '__main__': unittest.main()
