"""Offline contract tests adapted from Claude's ComputerTest.sh intentions.
No SSH or firewall calls leave this machine; the adapter is a traceable stub.
"""
import contextlib
import io
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import time
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import ComputerActions as act


class OperationalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        original = os.environ.copy()
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(original)))
        os.environ['HOME'] = str(self.root)
        os.environ['XDG_CONFIG_HOME'] = str(self.root / 'config')
        self.downloads = self.root / 'Downloads'
        self.downloads.mkdir()
        self.filename = self.downloads / 'artifact.zip'
        with zipfile.ZipFile(self.filename, 'w') as z:
            z.writestr('src/something.cls', '::class Test\n')
        with contextlib.redirect_stdout(io.StringIO()):
            act.add_root(f'add {self.downloads} to my find file locations', False)
        self.trace = self.root / 'argv.txt'
        self.stub = self.root / 'sshnode.sh'
        self.stub.write_text('#!/usr/bin/env bash\n'
                             'set -euo pipefail\n'
                             'case ed209b in\n'
                             '  ed209b) user=opc;;\n'
                             'esac\n'
                             'case "$*" in *ed209b*) ;; *) exit 3;; esac\n'
                             'printf "%s\\n" "$@" >> "$COMPUTER_TEST_ARGV_FILE"\n'
                             'echo "STUB: $*"\n')
        self.stub.chmod(0o700)
        os.environ['COMPUTER_SSHNODE'] = str(self.stub)
        os.environ['COMPUTER_TEST_ARGV_FILE'] = str(self.trace)

    def capture(self, fn, *args):
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            rc = fn(*args)
        return rc, stream.getvalue()

    def preview(self):
        rc, out = self.capture(act.deploy_prepare, 'deploy zipfile artifact.zip to ED209B')
        self.assertEqual(rc, 3)
        self.assertIn('NOT EXECUTED', out)
        token = re.search(r'Computer confirm ([A-Za-z0-9_-]{32})', out)
        self.assertIsNotNone(token, out)
        return token.group(1)

    def test_missing_node_is_not_local_fallback(self):
        for phrase in ('check free space on', 'check free memory on'):
            with self.subTest(phrase=phrase):
                with self.assertRaises(act.ComputerError) as ctx:
                    act.host_check(phrase, 'memory' in phrase)
                self.assertEqual(ctx.exception.status, 3)

    def test_local_space_and_memory_are_real_tools(self):
        os.environ['COMPUTER_DRY_RUN'] = '1'
        for txt in ('check free space', 'check free memory'):
            rc, output = self.capture(act.host_check, txt, 'memory' in txt)
            self.assertEqual(rc, 0)
            self.assertIn('DRY_RUN', output)
            self.assertIn('local', output)

    def test_remote_argv_and_correlated_job(self):
        rc, out = self.capture(act.host_check, 'check free space on ED209B', False)
        self.assertEqual(rc, 0)
        argv = self.trace.read_text().splitlines()
        self.assertEqual(argv[0], '--job-id')
        self.assertRegex(argv[1], r'^computer-check-free-space-ed209b-')
        self.assertEqual(argv[2:], ['ed209b', 'df', '-h'])

    def test_missing_ssh_adapter_refused(self):
        os.environ['COMPUTER_SSHNODE'] = str(self.root / 'missing')
        with self.assertRaises(act.ComputerError):
            act.host_check('check free space on ed209b', False)
        self.assertFalse(self.trace.exists())

    def test_unknown_node_refused(self):
        with self.assertRaises(act.ComputerError) as ctx:
            act.host_check('check free space on ed209f', False)
        self.assertEqual(ctx.exception.status, 4)
        self.assertFalse(self.trace.exists())

    def test_staged_transfer_is_single_use_with_verified_argv(self):
        token = self.preview()
        self.assertFalse(self.trace.exists(), 'preview must not call SSH')
        rc, out = self.capture(act.confirm_action, 'confirm ' + token)
        self.assertEqual(rc, 0)
        self.assertIn('OK transferred', out)
        argv = self.trace.read_text().splitlines()
        self.assertEqual(argv[0], '--job-id')
        self.assertRegex(argv[1], r'^computer-deploy-zipfile-ed209b-')
        self.assertEqual(argv[2:], ['--transfer', 'ed209b', str(self.filename)])
        with self.assertRaises(act.ComputerError):
            act.confirm_action('confirm ' + token)

    def test_pending_permissions_and_expiration(self):
        token = self.preview()
        item = act.pending_dir() / token
        self.assertEqual(stat.S_IMODE(item.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(item.parent.stat().st_mode), 0o700)
        data = json.loads(item.read_text())
        data['created_at'] -= act.CONFIRM_TTL_SECONDS + 1
        item.write_text(json.dumps(data))
        with self.assertRaises(act.ComputerError):
            act.confirm_action('confirm ' + token)
        self.assertFalse(item.exists())
        self.assertFalse(self.trace.exists())

    def test_changed_source_blocks_transfer_and_burns_token(self):
        token = self.preview()
        with zipfile.ZipFile(self.filename, 'a') as z:
            z.writestr('changed.txt', 'different')
        with self.assertRaises(act.ComputerError) as ctx:
            act.confirm_action('confirm ' + token)
        self.assertEqual(ctx.exception.status, 4)
        self.assertFalse(self.trace.exists())
        with self.assertRaises(act.ComputerError):
            act.confirm_action('confirm ' + token)

    def test_changed_adapter_blocks_transfer(self):
        token = self.preview()
        self.stub.write_text(self.stub.read_text() + '\n# modified after preview\n')
        with self.assertRaises(act.ComputerError):
            act.confirm_action('confirm ' + token)
        self.assertFalse(self.trace.exists())

    def test_multiple_matching_sources_require_explicit_path(self):
        other = self.root / 'other'
        other.mkdir()
        with zipfile.ZipFile(other / 'artifact.zip', 'w') as z:
            z.writestr('test', 'test')
        with contextlib.redirect_stdout(io.StringIO()):
            act.add_root(f'add {other} to my find file locations', False)
        with self.assertRaises(act.ComputerError) as ctx:
            act.deploy_prepare('deploy zipfile artifact.zip to ed209b')
        self.assertIn('Ambiguous ZIP', str(ctx.exception))
        self.assertFalse(self.trace.exists())

    def test_malformed_tokens_and_bad_zip(self):
        for phrase in ('confirm ../../etc/passwd', 'confirm notnumeric'):
            with self.subTest(phrase=phrase):
                with self.assertRaises(act.ComputerError):
                    act.confirm_action(phrase)
        self.filename.write_text('not a zip')
        with self.assertRaises(act.ComputerError):
            act.deploy_prepare('deploy zipfile artifact.zip to ed209b')
        self.assertFalse(self.trace.exists())

    def test_ssh_argument_injection_refused(self):
        for phrase in ('check free space on ed209b; touch /tmp/PWNED',
                       'deploy zipfile artifact.zip to ed209b; touch /tmp/PWNED'):
            with self.subTest(phrase=phrase):
                with self.assertRaises(act.ComputerError):
                    if phrase.startswith('check'):
                        act.host_check(phrase)
                    else:
                        act.deploy_prepare(phrase)
        self.assertFalse(self.trace.exists())


if __name__ == '__main__':
    unittest.main()
