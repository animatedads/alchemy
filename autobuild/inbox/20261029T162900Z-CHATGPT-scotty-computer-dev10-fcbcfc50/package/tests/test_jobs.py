"""Governed local and sshnode jobs, no real remote connection."""
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
import ComputerActions as computer


class RegisteredJobsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / 'config'
        self.trace = self.root / 'trace.json'
        self.ssh = self.root / 'sshnode.sh'
        self.ssh.write_text('''#!/usr/bin/env bash
set -euo pipefail
case ed209b in
  ed209b) user=opc;;
  ed209c) user=azureuser;;
esac
python3 - "$@" <<'RECORDER'
import json, os, sys
with open(os.environ['COMPUTER_TRACE'], 'w') as f:
    json.dump(sys.argv[1:], f)
RECORDER
''')
        self.ssh.chmod(0o700)
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.state),
                                        'COMPUTER_SSHNODE': str(self.ssh),
                                        'COMPUTER_TRACE': str(self.trace)}, clear=False)
        self.env.start()
        self.addCleanup(self.env.stop)

    def invoke(self, intent, utterance):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = computer.execute(intent, utterance)
        return code, buf.getvalue()

    def token(self, output, prefix):
        result = re.search(r'^' + re.escape(prefix) + r'([A-Za-z0-9_-]{32})$', output, re.M)
        self.assertIsNotNone(result, output)
        return result.group(1)

    def enroll(self, name, target, args):
        rc, text = self.invoke('JOBS', f'job draft {name} {target} -- ' + shlex.join(args))
        self.assertEqual(rc, 3)
        self.assertIn('NOT REGISTERED; NOT EXECUTED', text)
        token = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', text).group(1)
        rc, confirmed = self.invoke('JOBS', f'job approve {token} -- ' + shlex.join(args))
        self.assertEqual(rc, 3)
        self.assertIn('JOB_STRUCTURE_ATTESTED', confirmed)
        activate = self.token(confirmed, 'NOT REGISTERED until: Computer confirm ')
        rc, final = self.invoke('CONFIRM_ACTION', f'confirm {activate}')
        self.assertEqual(rc, 0)
        self.assertIn('JOB_REGISTERED', final)

    def test_local_exact_argv_receipts_and_replay(self):
        script = self.root / 'command.py'
        script.write_text('import sys\nprint(repr(sys.argv[1:]))\n')
        self.enroll('localjob', 'local', [sys.executable, str(script), '--name', 'file two.txt'])
        rc, preview = self.invoke('JOBS', 'job run localjob')
        self.assertEqual(rc, 3)
        self.assertIn('file two.txt', preview)
        token = self.token(preview, 'CONFIRM_RUN=Computer confirm ')
        rc, output = self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(rc, 0)
        self.assertIn('RESULT status=EXITED rc=0', output)
        receipt = re.search(r'RECEIPT stdout=(\S+)', output).group(1)
        self.assertIn("'--name', 'file two.txt'", Path(receipt).read_text())
        self.assertEqual(Path(receipt).stat().st_mode & 0o777, 0o600)
        with self.assertRaises(computer.ComputerError) as e:
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(e.exception.status, 4)

    def test_remote_adapter_exact_target_and_quoted_argument_boundaries(self):
        args = ['printf', '%s', "contains spaces; and 'quotes'", '$(touch /tmp/should-not-run)']
        self.enroll('remotejob', 'on ed209b', args)
        rc, preview = self.invoke('JOBS', 'job run remotejob')
        self.assertEqual(rc, 3)
        self.assertIn('REMOTE_EXECUTION=sshnode.sh', preview)
        token = self.token(preview, 'CONFIRM_RUN=Computer confirm ')
        rc, output = self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(rc, 0)
        actual = json.loads(self.trace.read_text())
        self.assertEqual(actual[0], '--job-id')
        self.assertEqual(actual[2], 'ed209b')
        self.assertEqual(shlex.split(actual[3]), args)
        self.assertEqual(len(actual), 4)

    def test_reordered_arguments_burn_review_token(self):
        args = ['/bin/echo', '--verbose', 'two words']
        rc, text = self.invoke('JOBS', 'job draft reorder local -- ' + shlex.join(args))
        self.assertEqual(rc, 3)
        token = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', text).group(1)
        with self.assertRaises(computer.ComputerError) as e:
            self.invoke('JOBS', f'job approve {token} -- /bin/echo "two words" --verbose')
        self.assertEqual(e.exception.status, 4)
        with self.assertRaises(computer.ComputerError) as e:
            self.invoke('JOBS', f'job approve {token} -- ' + shlex.join(args))
        self.assertEqual(e.exception.status, 4)
        self.assertNotIn('reorder', computer.load_state()['jobs'])

    def test_changed_local_executable_prevents_execution(self):
        executable = self.root / 'custom'
        executable.write_text('#!/bin/sh\necho first\n')
        executable.chmod(0o700)
        self.enroll('changed', 'local', [str(executable)])
        rc, output = self.invoke('JOBS', 'job run changed')
        token = self.token(output, 'CONFIRM_RUN=Computer confirm ')
        executable.write_text('#!/bin/sh\necho changed\n')
        with self.assertRaises(computer.ComputerError) as e:
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(e.exception.status, 4)

    def test_changed_sshnode_prevents_execution(self):
        self.enroll('sshchange', 'on ed209b', ['echo', 'remote'])
        rc, output = self.invoke('JOBS', 'job run sshchange')
        token = self.token(output, 'CONFIRM_RUN=Computer confirm ')
        self.ssh.write_text(self.ssh.read_text() + '# different adapter\n')
        with self.assertRaises(computer.ComputerError) as e:
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(e.exception.status, 4)
        self.assertFalse(self.trace.exists())

    def test_python_script_is_bound_and_mutation_blocks_execution(self):
        script = self.root / 'change.py'
        script.write_text('print("first")\n')
        self.enroll('scriptpin', 'local', [sys.executable, str(script)])
        rc, preview = self.invoke('JOBS', 'job run scriptpin')
        self.assertEqual(rc, 3)
        self.assertIn(str(script), preview)
        self.assertIn('PINNED_FILES=', preview)
        token = self.token(preview, 'CONFIRM_RUN=Computer confirm ')
        script.write_text('print("changed")\n')
        with self.assertRaises(computer.ComputerError) as ctx:
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(ctx.exception.status, 4)

    def test_python_script_mutation_blocks_approval(self):
        script = self.root / 'approve.py'
        script.write_text('print("first")\n')
        args = [sys.executable, str(script)]
        rc, preview = self.invoke('JOBS', 'job draft approvepin local -- ' + shlex.join(args))
        self.assertEqual(rc, 3)
        review_token = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', preview).group(1)
        script.write_text('print("different")\n')
        with self.assertRaises(computer.ComputerError) as ctx:
            self.invoke('JOBS', 'job approve ' + review_token + ' -- ' + shlex.join(args))
        self.assertEqual(ctx.exception.status, 4)

    def test_pin_file_explicit_dependency_blocks_execution(self):
        dependency = self.root / 'config.txt'
        dependency.write_text('original\n')
        draft = 'job draft extra local --pin-file ' + shlex.quote(str(dependency)) + ' -- /bin/echo hello'
        rc, preview = self.invoke('JOBS', draft)
        self.assertEqual(rc, 3)
        review_token = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', preview).group(1)
        rc, approval = self.invoke('JOBS', 'job approve ' + review_token + ' -- /bin/echo hello')
        self.assertEqual(rc, 3)
        activation = self.token(approval, 'NOT REGISTERED until: Computer confirm ')
        self.assertEqual(self.invoke('CONFIRM_ACTION', 'confirm ' + activation)[0], 0)
        rc, run = self.invoke('JOBS', 'job run extra')
        self.assertEqual(rc, 3)
        self.assertIn('config.txt', run)
        token = self.token(run, 'CONFIRM_RUN=Computer confirm ')
        dependency.write_text('altered\n')
        with self.assertRaises(computer.ComputerError) as ctx:
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(ctx.exception.status, 4)

    def test_local_pins_reject_symlinks_and_invalid_remote_scope(self):
        script = self.root / 'real.py'
        script.write_text('print("ok")\n')
        link = self.root / 'link.py'
        link.symlink_to(script)
        for draft in (
            'job draft badpin local -- ' + shlex.join([sys.executable, str(link)]),
            'job draft badpin local --pin-file ' + str(link) + ' -- /bin/echo hi',
            'job draft badpin on ed209b --pin-file ' + str(script) + ' -- /bin/echo hi',
            'job draft badpin local --pin-file relative.txt -- /bin/echo hi',
        ):
            with self.subTest(draft=draft), self.assertRaises(computer.ComputerError):
                self.invoke('JOBS', draft)

    def test_inline_shell_is_not_claimed_as_pinned_source(self):
        args = ['/usr/bin/bash', '-lc', 'echo ok']
        self.enroll('inline', 'local', args)
        rc, run = self.invoke('JOBS', 'job run inline')
        self.assertEqual(rc, 3)
        self.assertIn('PINNED_FILES=[]', run)
        self.assertIn('NOT pinned', run)

    def test_unknown_node_and_invalid_structure(self):
        for text in ('job draft nohost on ed209f -- echo hi',
                     'job draft bad local --cwd relative -- echo hi',
                     'job draft bad local --timeout 36000 -- echo hi',
                     'job draft bad local /bin/echo hello'):
            with self.subTest(text=text), self.assertRaises(computer.ComputerError):
                self.invoke('JOBS', text)
        self.assertFalse(self.trace.exists())

    def test_dry_run_does_not_execute_and_approval_is_consumed(self):
        self.enroll('dryremote', 'on ed209b', ['df', '-h'])
        rc, output = self.invoke('JOBS', 'job run dryremote')
        token = self.token(output, 'CONFIRM_RUN=Computer confirm ')
        with patch.dict(os.environ, {'COMPUTER_DRY_RUN': '1'}):
            rc, result = self.invoke('CONFIRM_ACTION', 'confirm ' + token)
        self.assertEqual(rc, 0)
        self.assertIn('process NOT executed', result)
        self.assertFalse(self.trace.exists())
        with self.assertRaises(computer.ComputerError):
            self.invoke('CONFIRM_ACTION', 'confirm ' + token)

    def test_revocation_rejects_pending_execution(self):
        self.enroll('retire', 'local', ['/bin/echo', 'hi'])
        rc, run = self.invoke('JOBS', 'job run retire')
        self.assertEqual(rc, 3)
        run_token = self.token(run, 'CONFIRM_RUN=Computer confirm ')
        rc, rev = self.invoke('JOBS', 'job revoke retire')
        self.assertEqual(rc, 3)
        self.assertIn('NOT REVOKED', rev)
        revoke_token = self.token(rev, 'Computer confirm ')
        rc, result = self.invoke('CONFIRM_ACTION', 'confirm ' + revoke_token)
        self.assertEqual(rc, 0)
        self.assertIn('JOB_REVOKED', result)
        with self.assertRaises(computer.ComputerError) as ctx:
            self.invoke('CONFIRM_ACTION', 'confirm ' + run_token)
        self.assertEqual(ctx.exception.status, 4)

    def test_immutable_registration(self):
        self.enroll('same', 'local', ['/bin/echo', 'hello'])
        with self.assertRaises(computer.ComputerError) as err:
            self.invoke('JOBS', 'job draft same local -- /bin/echo bye')
        self.assertEqual(err.exception.status, 4)


if __name__ == '__main__':
    unittest.main()
