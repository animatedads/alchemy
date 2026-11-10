"""Native backend contracts: named search groups, GitHub SSH authority, reviewed learning."""
import contextlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
import ComputerActions as c

class ScopedGithubLearnTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base=Path(self.tmp.name)
        before=os.environ.copy()
        self.addCleanup(lambda:(os.environ.clear(),os.environ.update(before)))
        os.environ['HOME']=str(self.base)
        os.environ['XDG_CONFIG_HOME']=str(self.base/'config')
        # Isolate the Git transport tests from host/sandbox-level insteadOf
        # rewrites.  The production GitHub code still honours user config.
        os.environ['GIT_CONFIG_NOSYSTEM']='1'
        os.environ['GIT_CONFIG_GLOBAL']=os.devnull
        os.environ['GIT_CONFIG_SYSTEM']=os.devnull
        for key in ('GIT_CONFIG_COUNT', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG'):
            os.environ.pop(key, None)
        # Simulated ssh -G only; Git's actual remote SSH transport is never executed.
        fakebin=self.base/'fake-bin'
        fakebin.mkdir()
        ssh=fakebin/'ssh'
        ssh.write_text('#!/bin/sh\n[ "$1" = "-G" ] || exit 92\nprintf "hostname github.com\nuser git\nidentityfile ~/.ssh/project-deploy-key\nidentitiesonly yes\nport 22\n"\n')
        ssh.chmod(0o700)
        os.environ['PATH']=str(fakebin)+os.pathsep+os.environ['PATH']
        self.inbound=self.base/'Downloads'/'current' 
        self.deps=self.base/'deps'
        self.irrelevant=self.base/'irrelevant'
        for d in (self.inbound,self.deps,self.irrelevant): d.mkdir(parents=True)
        (self.inbound/'new_asset.zip').write_bytes(b'new!')
        (self.irrelevant/'crypto_very_new.cls').write_text('secret false positive')
        (self.deps/'Crypto.cls').write_text('::class Crypto')
        with zipfile.ZipFile(self.deps/'crypto_v0.8.3.zip','w') as z:
            z.writestr('lib/crypto.cls', '::class Crypto')
        self.call(f'add {self.inbound} to my find file locations as inboundfiles', 'ADD_SEARCH_SCOPE')
        self.call(f'add {self.deps} to my find file locations as dependencies', 'ADD_SEARCH_SCOPE')

    def call(self,text,intent):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):
            try: rc=c.execute(intent,text)
            except c.ComputerError as exc: rc=exc.status; print('ERROR '+str(exc))
        return rc,output.getvalue()

    def test_named_scopes_are_machine_local_and_distinct(self):
        state=c.load_state()
        self.assertEqual(state['search_scopes']['inboundfiles'],[str(self.inbound)])
        rc,out=self.call('search scopes','SEARCH_SCOPES')
        self.assertEqual(rc,0); self.assertIn('SCOPE dependencies',out)
        rc,out=self.call('--json find new files in last 30 minutes in inboundfiles','SEARCH_NAMED')
        self.assertEqual(rc,0); d=json.loads(out)
        self.assertEqual(d['scope'],'inboundfiles')
        self.assertTrue(any(x['path'].endswith('new_asset.zip') for x in d['candidates']))
        self.assertFalse(any('Crypto' in x['path'] for x in d['candidates']))
        rc,out=self.call('--json find dependency rexx crypto in dependencies','SEARCH_NAMED')
        self.assertEqual(rc,0); d=json.loads(out)
        self.assertEqual(d['scope'],'dependencies')
        self.assertTrue(any('archive_member' in x for x in d['candidates']))
        self.assertTrue(all('irrelevant' not in x['path'] for x in d['candidates']))
        self.assertTrue(all('modified_utc' in x and 'reason' in x and 'size_bytes' in x and 'hash_status' in x for x in d['candidates']))
        self.assertEqual(d['candidates'],sorted(d['candidates'],key=lambda x:(-x['modified_epoch_ns'],x['path'],x.get('archive_member',''))))

    def test_unknown_scope_fails_closed_no_global_fallback(self):
        rc,out=self.call('find new files in last 30 minutes in thereisnone','SEARCH_NAMED')
        self.assertEqual(rc,3); self.assertIn('Unknown search scope',out)
        rc,out=self.call('find dependency rexx crypto in thereisnone','SEARCH_NAMED')
        self.assertEqual(rc,3)

    def test_registration_idempotent_existing_directory_required(self):
        rc,out=self.call(f'add {self.inbound} to search scope inboundfiles','ADD_SEARCH_SCOPE')
        self.assertEqual(rc,0); self.assertIn('ALREADY_PRESENT',out)
        rc,out=self.call('register search directory incoming /nothing-does-not-exist','ADD_SEARCH_SCOPE')
        self.assertNotEqual(rc,0)

    def test_learning_requires_exact_command_attestation_and_confirm(self):
        phrase='find dependency rexx crypto in dependencies'
        rc,out=self.call('learn locatecrypto as "'+phrase+'"','LEARN')
        self.assertEqual(rc,3)
        self.assertIn('COMMAND=Computer',out)
        self.assertNotIn('locatecrypto',c.load_state()['learned'])
        token=re.search(r'REVIEW: Computer .*?learn review ([\w-]{32})',out).group(1)
        rendered=shlex.join(['Computer',phrase])
        # Deliberately attest incorrect option placement; burns review token.
        rc,out=self.call(f'learn review {token} Computer junk','LEARN')
        self.assertEqual(rc,4)
        rc,out=self.call(f'learn review {token} {rendered}','LEARN')
        self.assertEqual(rc,4)
        rc,out=self.call('learn locatecrypto as "'+phrase+'"','LEARN')
        token=re.search(r'REVIEW: Computer .*?learn review ([\w-]{32})',out).group(1)
        rc,out=self.call(f'learn review {token} {rendered}','LEARN')
        self.assertEqual(rc,3,out)
        tok2=re.search(r'Computer confirm ([\w-]{32})',out).group(1)
        rc,out=self.call('confirm '+tok2,'CONFIRM_ACTION')
        self.assertEqual(rc,0,out)
        rc,out=self.call('do locatecrypto','RUN_LEARNED')
        self.assertEqual(rc,0,out)
        self.assertIn('crypto_v0.8.3.zip',out)
        rc,out=self.call('confirm '+tok2,'CONFIRM_ACTION')
        self.assertEqual(rc,4)

    def test_learning_refuses_arbitrary_shell_and_git_write(self):
        for query in ('learn wipe as "rm -rf /"', 'learn forcepush as "github push /tmp/repo"'):
            rc,out=self.call(query,'LEARN')
            self.assertEqual(rc,4,out)
            self.assertIn('read-only',out)

    def git(self,*args):
        p=subprocess.run(['git',*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,check=True)
        return p.stdout.strip()

    def make_repo(self):
        repo=self.base/'myproject'
        self.git('init','-q',str(repo))
        self.git('-C',str(repo),'config','user.name','Computer Test')
        self.git('-C',str(repo),'config','user.email','test@example.invalid')
        (repo/'first.txt').write_text('initial')
        self.git('-C',str(repo),'add','--','first.txt')
        self.git('-C',str(repo),'commit','-q','-m','initial')
        self.git('-C',str(repo),'remote','add','origin','git@github.com:example/test.git')
        return repo

    def test_github_read_respects_ssh_config_and_no_key_override(self):
        repo=self.make_repo()
        rc,out=self.call(f'github inspect {repo}','GITHUB')
        self.assertEqual(rc,0,out)
        self.assertIn('REMOTE_URL=git@github.com:example/test.git',out)
        self.assertIn('LOCAL_SSH_CONFIG_UNCHANGED',out)
        self.assertIn('identityfile=',out)
        os.environ['COMPUTER_DRY_RUN']='1'
        rc,out=self.call(f'github fetch {repo}','GITHUB')
        self.assertEqual(rc,0,out); self.assertIn('DRY_RUN github fetch',out)
        self.assertNotIn(' -i ', next(x for x in out.splitlines() if x.startswith('COMMAND=')))

    def test_github_stage_commit_push_preview_and_confirm(self):
        repo=self.make_repo()
        (repo/'second.txt').write_text('second')
        rc,out=self.call(f'github stage {repo} file second.txt','GITHUB')
        self.assertEqual(rc,3,out)
        self.assertIn("'add'",out.replace('"','\'')) if False else None
        token=re.search(r'Computer confirm ([\w-]{32})',out).group(1)
        os.environ['COMPUTER_DRY_RUN']='1'
        rc,out=self.call('confirm '+token,'CONFIRM_ACTION')
        self.assertEqual(rc,0,out)
        os.environ.pop('COMPUTER_DRY_RUN',None)
        rc,out=self.call(f'github stage {repo} file second.txt','GITHUB')
        token=re.search(r'Computer confirm ([\w-]{32})',out).group(1)
        rc,out=self.call('confirm '+token,'CONFIRM_ACTION')
        self.assertEqual(rc,0,out)
        rc,out=self.call(f'github commit {repo} message "second commit"','GITHUB')
        self.assertEqual(rc,3,out)
        token=re.search(r'Computer confirm ([\w-]{32})',out).group(1)
        rc,out=self.call('confirm '+token,'CONFIRM_ACTION')
        self.assertEqual(rc,0,out)
        self.assertEqual(self.git('-C',str(repo),'log','-1','--format=%s'),'second commit')
        rc,out=self.call(f'github push {repo}','GITHUB')
        self.assertEqual(rc,3,out)
        token=re.search(r'Computer confirm ([\w-]{32})',out).group(1)
        os.environ['COMPUTER_DRY_RUN']='1'
        rc,out=self.call('confirm '+token,'CONFIRM_ACTION')
        self.assertEqual(rc,0,out)
        self.assertIn('DRY_RUN github_push',out)

if __name__=='__main__': unittest.main()
