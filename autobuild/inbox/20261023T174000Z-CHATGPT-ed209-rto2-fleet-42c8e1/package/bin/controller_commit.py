#!/usr/bin/env python3
"""Owning-MU durable RTO2 receipt publisher; ingress crypto verified separately by native XTP."""
import argparse, datetime as dt, hashlib, json, os, pathlib, re, sys
def check(receipt, run_id, mi, mu, n, epoch):
    if receipt.get('schema') != 'ed209.rto2.controller-receipt/1':raise ValueError('wrong schema')
    if (receipt.get('run_id'),receipt.get('mi_id'),receipt.get('mu_id')) != (run_id,mi,mu):raise ValueError('identity mismatch')
    if receipt.get('controller_id')!='GRID.MU.'+mu or receipt.get('delivery')!='authenticated-xtp-qf-wire-response':
        raise ValueError('unverified controller')
    r=receipt.get('rto2',{})
    expected=n*(n+1)//2
    checks={'schema':'rexxos.rto2.smoke.result/1','run_id':run_id,'node_id':mi,'n':n,'value':expected,
       'committed_value':expected,'committed_sequence':1,'epoch':epoch,'role':'ACTIVE','rto2_api':'alchemy.rto/0.1',
       'rto2_lifecycle':'CAPTURED','rto2_identity':f'ED209.SMOKE.{run_id}:{mi}'}
    for name,value in checks.items():
        if r.get(name)!=value or isinstance(r.get(name),bool):raise ValueError('invalid RTO2 '+name)
    if r.get('rto2_state')!={'value':expected,'committedValue':expected}:raise ValueError('RTO2 capture mismatch')
    if not re.fullmatch(r'[A-Za-z0-9._-]{1,80}',run_id):raise ValueError('invalid run id')
    if not re.fullmatch(r'MN[12]-ED209[A-Z]',mi):raise ValueError('invalid MI id')
    if mu!='MU-'+mi[4:]:raise ValueError('owning MU mismatch')
    return expected

def publish(directory,receipt,run_id,mi,mu,n,epoch):
    check(receipt,run_id,mi,mu,n,epoch)
    root=pathlib.Path(directory).resolve();root.mkdir(parents=True,exist_ok=True,mode=0o700)
    run=root/run_id;run.mkdir(exist_ok=True,mode=0o700)
    target=run/(mi+'.json');lock=run/('.lock.'+mi)
    os.mkdir(lock,0o700)
    try:
        canonical=json.dumps(receipt,sort_keys=True,separators=(',',':')).encode()
        digest=hashlib.sha256(canonical).hexdigest()
        if target.exists():
            previous=json.loads(target.read_text())
            if previous.get('receipt_sha256')!=digest:raise ValueError('immutable receipt conflict')
            return previous
        published={**receipt,'controller_commit':'DURABLE_LOCAL_RECEIPT','receipt_sha256':digest,
                   'committed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat()}
        tmp=run/('.'+mi+'.'+str(os.getpid())+'.tmp')
        try:
            fd=os.open(tmp,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
            with os.fdopen(fd,'wb') as stream:
                stream.write((json.dumps(published,sort_keys=True,separators=(',',':'))+'\n').encode())
                stream.flush();os.fsync(stream.fileno())
            os.replace(tmp,target)
            dfd=os.open(run,os.O_RDONLY|os.O_DIRECTORY)
            try:os.fsync(dfd)
            finally:os.close(dfd)
        finally:tmp.unlink(missing_ok=True)
        return published
    finally:os.rmdir(lock)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',required=True);p.add_argument('--mi',required=True);p.add_argument('--mu',required=True)
    p.add_argument('--n',type=int,default=1000);p.add_argument('--epoch',type=int,default=1);p.add_argument('--store',required=True)
    a=p.parse_args()
    try:print(json.dumps(publish(a.store,json.loads(sys.stdin.read(65536)),a.run,a.mi,a.mu,a.n,a.epoch),sort_keys=True))
    except Exception as e:print('CONTROLLER_COMMIT_FAILED: '+str(e),file=sys.stderr);sys.exit(1)
