#!/usr/bin/env python3
"""MU-local durable receipt publisher. Network reply is authenticated by native ooRexx transport beforehand."""
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import sys

def check(receipt, run_id, mi, mu, n, epoch):
    if receipt.get('schema') != 'ed209.rto2.controller-receipt/1':
        raise ValueError('wrong controller receipt schema')
    if (receipt.get('run_id'), receipt.get('mi_id'), receipt.get('mu_id')) != (run_id, mi, mu):
        raise ValueError('controller/MI binding mismatch')
    if receipt.get('controller_id') != 'GRID.MU.' + mu or receipt.get('delivery') != 'authenticated-xtp-qf-wire-response':
        raise ValueError('unverified delivery or controller')
    r = receipt.get('rto2', {})
    expected = n * (n+1) // 2
    checks = {
        'schema': 'rexxos.rto2.smoke.result/1', 'run_id': run_id,
        'node_id': mi, 'n': n, 'value': expected,
        'committed_value': expected, 'committed_sequence': 1,
        'epoch': epoch, 'role': 'ACTIVE', 'rto2_api': 'alchemy.rto/0.1',
        'rto2_lifecycle': 'CAPTURED',
        'rto2_identity': f'ED209.SMOKE.{run_id}:{mi}'
    }
    for field, value in checks.items():
        if r.get(field) != value or isinstance(r.get(field), bool):
            raise ValueError(f'invalid RTO2 {field}')
    if r.get('rto2_state') != {'value': expected, 'committedValue': expected}:
        raise ValueError('RTO2 captured committed state does not match')
    if not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', run_id):
        raise ValueError('invalid run identifier')
    if not re.fullmatch(r'MN[12]-ED209[A-Z]', mi):
        raise ValueError('invalid MI identity')
    return expected

def publish(directory, receipt, run_id, mi, mu, n, epoch):
    check(receipt, run_id, mi, mu, n, epoch)
    root = pathlib.Path(directory).resolve()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    run = root / run_id
    run.mkdir(mode=0o700, exist_ok=True)
    target = run / (mi + '.json')
    lock = run / ('.lock.'+mi)
    os.mkdir(lock, 0o700)
    try:
        canonical = json.dumps(receipt, sort_keys=True, separators=(',', ':')).encode()
        if target.exists():
            previous = json.loads(target.read_text())
            if previous.get('receipt_sha256') != hashlib.sha256(canonical).hexdigest():
                raise ValueError('immutable receipt conflict; do not overwrite')
            return previous
        published = {
            **receipt, 'controller_commit': 'DURABLE_LOCAL_RECEIPT',
            'receipt_sha256': hashlib.sha256(canonical).hexdigest(),
            'committed_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        }
        contents = (json.dumps(published, sort_keys=True, separators=(',', ':'))+'\n').encode()
        tmp = run / ('.'+mi+'.'+str(os.getpid())+'.tmp')
        try:
            fd = os.open(tmp, os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'wb') as f:
                f.write(contents)
                f.flush(); os.fsync(f.fileno())
            os.replace(tmp, target)
            dirfd = os.open(run, os.O_RDONLY|os.O_DIRECTORY)
            try: os.fsync(dirfd)
            finally: os.close(dirfd)
        finally:
            tmp.unlink(missing_ok=True)
        return published
    finally:
        os.rmdir(lock)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--run', required=True)
    p.add_argument('--mi', required=True)
    p.add_argument('--mu', required=True)
    p.add_argument('--n', type=int, default=1000)
    p.add_argument('--epoch', type=int, default=1)
    p.add_argument('--store', required=True)
    a = p.parse_args()
    try:
        incoming = sys.stdin.read(65536)
        obj = json.loads(incoming)
        published = publish(a.store,obj,a.run,a.mi,a.mu,a.n,a.epoch)
        print(json.dumps(published, sort_keys=True))
    except Exception as exc:
        print('CONTROLLER_COMMIT_FAILED: '+str(exc), file=sys.stderr)
        sys.exit(1)
