#!/usr/bin/env python3
"""Policy status semantics without requiring root or mutating system paths."""
from pathlib import Path
import subprocess
import sys
import tempfile

p=Path(__file__).parent.parent / 'src/ssh_xtp_policy.py'
with tempfile.TemporaryDirectory(prefix='sshxtp-pol-') as t:
    state=Path(t)/'state'
    out=subprocess.run([sys.executable,str(p),'--file',str(state),'status'],capture_output=True,check=True)
    assert b'"mode": "SEALED"' in out.stdout
    state.write_text('LOCKED\n')
    out=subprocess.run([sys.executable,str(p),'--file',str(state),'status'],capture_output=True,check=True)
    # A user-owned file is deliberately rejected by production policy reader.
    if __import__('os').geteuid()!=0:
        assert b'"mode": "SEALED"' in out.stdout
    state.chmod(0o666)
    out=subprocess.run([sys.executable,str(p),'--file',str(state),'status'],capture_output=True,check=True)
    assert b'"mode": "SEALED"' in out.stdout
    state.chmod(0o600)
    state.write_text('BAD\n')
    out=subprocess.run([sys.executable,str(p),'--file',str(state),'status'],capture_output=True,check=True)
    assert b'"mode": "SEALED"' in out.stdout
    print('PASS root-owned fail-closed policy status')

if __import__('os').geteuid() == 0:
    with tempfile.TemporaryDirectory(prefix='sshxtp-rootpolicy-') as t:
        state=Path(t)/'state'
        cli=[sys.executable,str(p),'--file',str(state)]
        for desired in ('OPEN','LOCKED','SEALED'):
            o=subprocess.run(cli+['set',desired,'--ticket','LOCAL-TEST-1'],capture_output=True,check=True)
            assert ('"mode": "'+desired+'"').encode() in o.stdout, o.stderr
            check=subprocess.run(cli+['status'],capture_output=True,check=True)
            assert ('"mode": "'+desired+'"').encode() in check.stdout
        events=(Path(t)/'state.audit.jsonl').read_text().splitlines()
        assert len(events)==6
        assert sum('"phase": "committed"' in e for e in events)==3
        print('PASS root-admin atomic OPEN/LOCKED/SEALED plus audit intent/commit')
