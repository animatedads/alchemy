#!/usr/bin/env python3
"""Strict service-registry and degradation-policy admission regressions."""
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parent.parent
BIN=ROOT/'bin/ssh-xtp'

def freeport():
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:
        s.bind(('127.0.0.1',0))
        return s.getsockname()[1]

def run_case(name, service_line, class_line, *, state='normal', expected_start=True, wrong_client_service=False):
    with tempfile.TemporaryDirectory(prefix='xtp-svc-') as d:
        base=Path(d)
        s,c=freeport(),freeport()
        while c==s:c=freeport()
        (base/'routes.tsv').write_text(
            f'server_ingress\t4\tudp\t127.0.0.1:{s}\t\t100\t1\t\t0\n'
            f'client_ingress\t4\tudp\t127.0.0.1:{c}\t\t100\t1\t\t0\n')
        (base/'key').write_text(secrets.token_hex(32)+'\n')
        (base/'state').write_text('OPEN\n')
        (base/'services.tsv').write_text(service_line+'\n')
        (base/'operational.tsv').write_text(class_line+'\n')
        for f in ['key','state','services.tsv','operational.tsv']:(base/f).chmod(0o600)
        env=os.environ|{'XTP_ROUTE_FILE':str(base/'routes.tsv'),'XTP_HEALTH_FILE':str(base/'health.tsv')}
        gw=[str(BIN),'gateway','--rx-peer','server_ingress','--tx-peer','client_ingress',
            '--key-file',str(base/'key'),'--policy-file',str(base/'state'),'--client-id','testnode',
            '--ssh-port','22','--idle-seconds','6','--service-registry',str(base/'services.tsv'),
            '--operational-registry',str(base/'operational.tsv'),'--operating-state',state,
            '--allow-user-owned-policy-for-test','yes','--allow-user-owned-registry-for-test','yes']
        if not expected_start:
            r=subprocess.run(gw,env=env,capture_output=True,text=True,timeout=5)
            assert r.returncode!=0,(name,r.stderr)
        else:
            proc=subprocess.Popen(gw,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            try:
                time.sleep(.3)
                assert proc.poll() is None,(name,proc.communicate(timeout=2))
                if wrong_client_service:
                    # Send an unauthorized FIRST through the actual native XTP 3.4
                    # transport and verify it never gets a control ACK.
                    xtp=ROOT/'cli-test'
                    cmd=[str(xtp),'server_ingress','--service','backup.bulk',
                         '--message','reject-me','--timeout-ms','150','--retries','2']
                    r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=6)
                    assert r.returncode!=0,(name,r.stdout,r.stderr)
                    assert proc.poll() is None,'listener terminated on unauthorized FIRST'
            finally:
                if proc.poll() is None:proc.terminate()
                proc.communicate(timeout=4)
        print('PASS',name,flush=True)

ssh='ssh.management\tMANAGEMENT.CRITICAL\tserver_ingress\tssh.management\t1\tSSH gateway'
active='MANAGEMENT.CRITICAL\tallow\tallow\tallow\tallow'
run_case('registered service creates native XTP listener',ssh,active)
run_case('unknown service denied before XTP ACK',ssh,active,wrong_client_service=True)
run_case('missing service rejected at gateway startup', 'backup.bulk\tBACKGROUND.BULK\tserver_ingress\tbackup.bulk\t1\tBulk',active,expected_start=False)
run_case('disabled service rejected at gateway startup',ssh.replace('\t1\tSSH','\t0\tSSH'),active,expected_start=False)
run_case('wrong logical access peer rejected at gateway startup',ssh.replace('\tserver_ingress\t','\telsewhere\t'),active,expected_start=False)
run_case('unregistered class rejected',ssh,'BACKGROUND.BULK\tallow\tallow\tallow\tallow',expected_start=False)
run_case('critical class retained in emergency',ssh,active,state='emergency')
run_case('emergency class refusal blocks listener',ssh,'MANAGEMENT.CRITICAL\tallow\tallow\tallow\trefuse-forward',state='emergency',expected_start=False)
run_case('unsupported throttle denied rather than bypassed',ssh,'MANAGEMENT.CRITICAL\tallow\tthrottle:50\tallow\tallow',state='degraded',expected_start=False)

# Planner dev3 capacity scopes must not be silently bypassed by an SSH bridge
# that implements only session-level admission (and has no capacity scheduler).
run_case('per-context cap denied until implemented',ssh,
    'MANAGEMENT.CRITICAL\tallow:100:allow:any:30:1:100\tallow\tallow\tallow',expected_start=False)
run_case('aggregate class cap denied until implemented',ssh,
    'MANAGEMENT.CRITICAL\tallow:100:allow:any:100:1:60\tallow\tallow\tallow',expected_start=False)
run_case('parallel contexts policy denied until implemented',ssh,
    'MANAGEMENT.CRITICAL\tallow:100:allow:any:100:2:100\tallow\tallow\tallow',expected_start=False)
