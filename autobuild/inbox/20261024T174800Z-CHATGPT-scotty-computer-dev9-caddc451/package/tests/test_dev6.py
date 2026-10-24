"""Dev6 receipt access, bounded search, and explicitly approved repeat diagnostic policy."""
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
import ComputerJobs as j


class Dev6Test(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.root / 'cfg'),
                                        'COMPUTER_TRACE': str(self.root / 'trace')})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.ssh = self.root / 'sshnode.sh'
        self.ssh.write_text('''#!/bin/sh
case "$1" in
  ed209b) user=opc;;
esac
printf '%s\\n' "$@" > "$COMPUTER_TRACE"
''')
        self.ssh.chmod(0o700)
        self.sshenv = patch.dict(os.environ, {'COMPUTER_SSHNODE': str(self.ssh)})
        self.sshenv.start()
        self.addCleanup(self.sshenv.stop)

    def call(self, intent, text):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = c.execute(intent, text)
        return rc, buf.getvalue()

    def token(self, preview, label='Computer confirm '):
        matches = re.findall(re.escape(label) + r'([A-Za-z0-9_-]{32})', preview)
        self.assertTrue(matches, preview)
        return matches[-1]

    def enroll(self, name, argv, remote=False):
        target = 'on ed209b' if remote else 'local'
        rc, draft = self.call('JOBS', 'job draft ' + name + ' ' + target + ' -- ' + shlex.join(argv))
        self.assertEqual(rc, 3)
        tok = re.search(r'job approve ([A-Za-z0-9_-]{32}) -- ', draft).group(1)
        rc, approved = self.call('JOBS', 'job approve ' + tok + ' -- ' + shlex.join(argv))
        self.assertEqual(rc, 3)
        rc, done = self.call('CONFIRM_ACTION', 'confirm ' + self.token(approved))
        self.assertEqual(rc, 0)

    def run_once(self, name):
        rc, preview = self.call('JOBS', 'job run ' + name)
        self.assertEqual(rc, 3)
        rc, executed = self.call('CONFIRM_ACTION', 'confirm ' + self.token(preview))
        self.assertEqual(rc, 0)
        return re.search(r'JOB_RESULT_COMMAND=Computer job result (computer-job-[a-z0-9_-]+)', executed).group(1)

    def policy(self, name, mode):
        rc, preview = self.call('JOBS', f'job policy {name} {mode}')
        self.assertEqual(rc, 3)
        self.assertIn('NOT CHANGED', preview)
        return self.call('CONFIRM_ACTION', 'confirm ' + self.token(preview))

    def test_result_stdout_stderr_explain_and_history_no_new_job(self):
        script = self.root / 'probe.py'
        script.write_text("import sys\nprint('SUCCESS-TEST')\nprint('FAULT-TEST', file=sys.stderr)\n")
        self.enroll('probe', [sys.executable, str(script)])
        run = self.run_once('probe')
        rc, data = self.call('JOBS', '--json job result ' + run)
        self.assertEqual(rc, 0)
        doc = json.loads(data)
        self.assertEqual(doc['schema'], j.RUN_SCHEMA)
        self.assertEqual(doc['child_rc'], 0)
        self.assertEqual(Path(doc['stdout_path']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(doc['stdout_path']).with_suffix('.json').stat().st_mode & 0o777, 0o600)
        self.assertIn('SUCCESS-TEST', self.call('JOBS', 'job stdout ' + run)[1])
        self.assertIn('FAULT-TEST', self.call('JOBS', 'job stderr ' + run)[1])
        self.assertIn('EXPLANATION=child exited zero', self.call('JOBS', 'job explain ' + run)[1])
        self.assertIn(run, self.call('JOBS', 'job history probe')[1])
        self.assertIn(run, self.call('JOBS', '--json job history probe')[1])
        self.assertNotIn('JOB_EXECUTE', self.call('JOBS', 'job result ' + run)[1])

    def test_failures_retained_and_failed_child_is_not_success(self):
        self.enroll('failprobe', ['/bin/false'])
        rc, preview = self.call('JOBS', 'job run failprobe')
        rc, output = self.call('CONFIRM_ACTION', 'confirm ' + self.token(preview))
        self.assertEqual(rc, 5)
        run = re.search(r'JOB_RESULT_COMMAND=Computer job result (computer-job-[a-z0-9_-]+)', output).group(1)
        rc, data = self.call('JOBS', '--json job result ' + run)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(data)['child_rc'], 1)
        self.assertIn('failed', self.call('JOBS', 'job explain ' + run)[1])

    def test_receipt_limits_unknown_and_symlink_refused(self):
        self.enroll('bounded', ['/bin/echo', 'good'])
        run = self.run_once('bounded')
        with self.assertRaises(c.ComputerError) as ex:
            self.call('JOBS', 'job stdout ../../etc/passwd')
        self.assertEqual(ex.exception.status, 2)
        root = c.config_dir() / 'jobs'
        stdout = root / (run + '.stdout')
        stdout.unlink()
        (self.root / 'secret').write_text('SECRET')
        stdout.symlink_to(self.root / 'secret')
        with self.assertRaises(c.ComputerError):
            self.call('JOBS', 'job stdout ' + run)
        stdout.unlink()
        stdout.write_bytes(b'X' * (j.RECEIPT_READ_LIMIT + 25))
        stdout.chmod(0o600)
        rc, text = self.call('JOBS', 'job stdout ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('truncated=True', text)
        self.assertNotIn('SECRET', text)

    def test_repeat_policy_requires_explicit_confirmation_and_blocks_shell(self):
        self.enroll('disk', ['df', '-h'])
        rc, preview = self.call('JOBS', 'job run disk')
        self.assertEqual(rc, 3)
        rc, answer = self.policy('disk', 'repeat-readonly')
        self.assertEqual(rc, 0)
        self.assertIn('JOB_POLICY_APPLIED', answer)
        rc, output = self.call('JOBS', 'job run disk')
        self.assertEqual(rc, 0)
        self.assertIn('policy=repeat-readonly', output)
        self.assertIn('RESULT status=EXITED rc=0', output)
        self.assertNotIn('CONFIRM_RUN=', output)
        self.assertEqual(self.policy('disk', 'manual')[0], 0)
        self.assertEqual(self.call('JOBS', 'job run disk')[0], 3)
        self.enroll('danger', ['/bin/sh', '-c', 'echo hi'])
        with self.assertRaises(c.ComputerError) as ex:
            self.call('JOBS', 'job policy danger repeat-readonly')
        self.assertEqual(ex.exception.status, 4)

    def test_remote_repeat_revocation_and_adapter_change(self):
        self.enroll('rdisk', ['df', '-h'], remote=True)
        self.assertEqual(self.policy('rdisk', 'repeat-readonly')[0], 0)
        rc, out = self.call('JOBS', 'job run rdisk')
        self.assertEqual(rc, 0)
        self.assertIn('TARGET=ed209b', out)
        self.assertIn('df -h', self.root.joinpath('trace').read_text())
        self.ssh.write_text(self.ssh.read_text() + '# changed\n')
        with self.assertRaises(c.ComputerError) as ex:
            self.call('JOBS', 'job run rdisk')
        self.assertEqual(ex.exception.status, 4)

    def test_remote_reusable_policy_refuses_changed_local_ssh_config(self):
        with patch.dict(os.environ, {'HOME': str(self.root)}):
            ssh_dir = self.root / '.ssh'
            ssh_dir.mkdir()
            conf = ssh_dir / 'config'
            conf.write_text('Host *\n  BatchMode yes\n')
            conf.chmod(0o600)
            self.enroll('configpin', ['df', '-h'], remote=True)
            self.assertEqual(self.policy('configpin', 'repeat-readonly')[0], 0)
            conf.write_text('Host *\n  BatchMode no\n')
            with self.assertRaises(c.ComputerError) as exc:
                self.call('JOBS', 'job run configpin')
            self.assertEqual(exc.exception.status, 4)
            self.assertFalse((self.root / 'trace').exists())

    def test_scope_discovery_is_bounded_and_does_not_cross_scopes(self):
        roots = self.root / 'work'
        roots.mkdir()
        found = roots / 'xtp-source'
        found.mkdir()
        (found / 'project').mkdir()
        (roots / 'unrelated').mkdir()
        foreign = self.root / 'elsewhere'
        (foreign / 'xtp-hidden').mkdir(parents=True)
        (roots / 'symlink-to-elsewhere').symlink_to(foreign, target_is_directory=True)
        self.call('ADD_SEARCH_SCOPE', f'add {roots} to my find file locations as xtpwork')
        rc, out = self.call('FIND_DIRECTORIES', '--json find directories matching xtp in xtpwork')
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertTrue(data['complete'])
        self.assertEqual(data['count'], 1)
        self.assertEqual(data['candidates'][0]['path'], str(found))
        self.assertNotIn('xtp-hidden', out)
        with self.assertRaises(c.ComputerError) as ex:
            self.call('FIND_DIRECTORIES', 'find directories matching xtp in unknown')
        self.assertEqual(ex.exception.status, 3)

    def test_scope_discovery_budget_not_false_not_found(self):
        from unittest.mock import patch as mocked
        roots = self.root / 'work'
        roots.mkdir()
        for ix in range(5):
            (roots / ('no-' + str(ix))).mkdir()
        self.call('ADD_SEARCH_SCOPE', f'add {roots} to my find file locations as testscope')
        import ComputerSearch as search
        # Force limited budget using a wrapper around os.scandir count? Instead
        # force depth saturation and demand incomplete status.
        with mocked.object(search, 'find_directories', wraps=search.find_directories):
            deep = roots
            for ix in range(17):
                deep = deep / ('level' + str(ix))
                deep.mkdir()
            rc, text = self.call('FIND_DIRECTORIES', 'find directories matching absent in testscope')
            self.assertEqual(rc, 3)
            self.assertIn('INCOMPLETE', text)


    def test_legacy_receipt_reports_unknown_not_success(self):
        import ComputerJobs as jobs
        run = 'computer-job-oldrun-' + 'a' * 16
        root = c.config_dir() / 'jobs'
        root.mkdir(parents=True)
        out = root / (run + '.stdout')
        out.write_text('looks okay, but not verified')
        out.chmod(0o600)
        rc, text = self.call('JOBS', 'job explain ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('UNKNOWN_LEGACY', text)
        self.assertIn('status is UNKNOWN', text)
        rc, text = self.call('JOBS', 'job result ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('"child_rc": null', text)
        rc, text = self.call('JOBS', 'job stdout ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('metadata=UNVERIFIED_LEGACY', text)
        self.assertNotIn('RESULT status=EXITED', text)

    def test_codex_timestamped_legacy_receipt_in_receipts_folder(self):
        run = 'computer-job-copy-firewall-stderr-20261014T122430Z-d68f2048'
        root = c.config_dir() / 'jobs' / 'receipts'
        root.mkdir(parents=True)
        path = root / (run + '.stderr')
        path.write_text('Authorization failed.\n')
        path.chmod(0o600)
        rc, text = self.call('JOBS', 'job stderr ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('Authorization failed.', text)
        self.assertIn('UNVERIFIED_LEGACY', text)
        rc, text = self.call('JOBS', 'job result ' + run)
        self.assertEqual(rc, 0)
        self.assertIn('UNKNOWN_LEGACY', text)

    def test_policy_revocation_on_job_revoke(self):
        self.enroll('oldjob', ['date', '-u'])
        self.assertEqual(self.policy('oldjob', 'repeat-readonly')[0], 0)
        self.assertIn('oldjob', c.load_state()['job_policies'])
        rc, out = self.call('JOBS', 'job revoke oldjob')
        self.assertEqual(rc, 3)
        self.assertEqual(self.call('CONFIRM_ACTION', 'confirm ' + self.token(out))[0], 0)
        self.assertNotIn('oldjob', c.load_state()['job_policies'])
        with self.assertRaises(c.ComputerError) as ex:
            self.call('JOBS', 'job run oldjob')
        self.assertEqual(ex.exception.status, 1)


if __name__ == '__main__':
    unittest.main()
