#!/usr/bin/env python3
"""ED209: submit work through each owning MU's native authenticated XTP controller, centrally sort durable RTO2 receipts.

SSH is a management-plane launcher/receipt readback to MUs ONLY; it never invokes a guest or transfers a work result from a guest.
"""
import argparse
import csv
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys

# Existing accepted MI allocation: first eight original MUs, then F (17/18) and H (19/20).
ROUTES = ['a','b','c','d','e','i','j','k','f','h']
TARGETS = [(2*i+j+1, f'ed209{host}', f'MU-ED209{host.upper()}', f'MN{j+1}-ED209{host.upper()}')
           for i,host in enumerate(ROUTES) for j in range(2)]

def check_receipt(obj, route, alias, mu, mi, run_id, n, epoch):
    from controller_commit import check
    value = check(obj, run_id,mi,mu,n,epoch)
    if obj.get('controller_commit')!='DURABLE_LOCAL_RECEIPT':
        raise ValueError('controller did not durably publish result')
    if not re.fullmatch(r'[a-f0-9]{64}',obj.get('receipt_sha256','')):
        raise ValueError('missing canonical receipt digest')
    to_hash = {k:v for k,v in obj.items() if k not in ('controller_commit','committed_at_utc','receipt_sha256')}
    import hashlib
    canonical=json.dumps(to_hash,sort_keys=True,separators=(',',':')).encode()
    if hashlib.sha256(canonical).hexdigest()!=obj['receipt_sha256']:
        raise ValueError('controller receipt digest mismatch')
    return {'route':route,'host':alias,'mu':mu,'mi':mi,'status':'PASS', 'value':value,
            'rto2_sequence':obj['rto2']['committed_sequence'],'rto2_epoch':epoch,
            'receipt_sha256':obj['receipt_sha256'],'committed_at_utc':obj['committed_at_utc']}

def run(args):
    if not re.fullmatch(r'[A-Za-z0-9._-]{1,80}',args.run):
        raise ValueError('unsafe run identifier')
    if not (1 <= args.n <= 1000) or args.epoch < 1:
        raise ValueError('invalid work bound or epoch')
    selected = [x for x in TARGETS if not args.only or x[1] in args.only]
    if args.only and set(args.only)-set(x[1] for x in TARGETS):
        raise ValueError('unknown host selection')
    if not args.dry_run and not pathlib.Path(args.sshnode).is_file():
        raise ValueError('sshnode.sh not found')
    if args.dry_run:
        for route,host,mu,mi in selected:
            print(f'PLAN route={route} controller={mu} host={host} MI={mi} n={args.n}')
        return 0
    destination=pathlib.Path(args.output)
    destination.mkdir(parents=True,exist_ok=False)
    os.chmod(destination,0o700)
    results=[]; errors=[]
    for route,host,mu,mi in selected:
        remote=' '.join(shlex.quote(x) for x in ['bash', args.controller_script, args.run, mi, str(args.n)])
        try:
            p=subprocess.run([args.sshnode,host,remote],text=True,capture_output=True,timeout=args.timeout,check=False)
            if p.returncode!=0:
                raise RuntimeError(f'controller command rc={p.returncode}; {p.stderr.strip()[-300:]}')
            lines=[x for x in p.stdout.splitlines() if x.strip().startswith('{')]
            if len(lines)!=1:
                raise ValueError('expected exactly one controller-produced JSON receipt')
            obj=json.loads(lines[0])
            row=check_receipt(obj,route,host,mu,mi,args.run,args.n,args.epoch)
            results.append(row)
            print(f'PASS {route:02d} {mi} via {mu}: {row["value"]}',flush=True)
        except Exception as exc:
            errors.append({'route':route,'mi':mi,'controller':mu,'reason':str(exc)})
            print(f'FAIL {route:02d} {mi}: {str(exc)}',file=sys.stderr,flush=True)
    results.sort(key=lambda x:x['route'])
    with (destination/'results_by_route.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['route','host','mu','mi','status','value','rto2_sequence','rto2_epoch','receipt_sha256','committed_at_utc']);writer.writeheader();writer.writerows(results)
    with (destination/'results_by_value.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['route','host','mu','mi','status','value','rto2_sequence','rto2_epoch','receipt_sha256','committed_at_utc']);writer.writeheader();writer.writerows(sorted(results,key=lambda x:(x['value'],x['route'])))
    expected = 20 if not args.only else len(selected)
    status='PASS' if not errors and len(results)==expected and len({x['mi'] for x in results})==expected else 'FAIL'
    summary={'schema':'ed209.rto2.mesh-sort.summary/1','run_id':args.run,
        'scope':'FULL_20_MI' if not args.only else 'SUBSET_NOT_FULL_ESTATE',
        'qualification_boundary':'LOCAL_MI_EXECUTION_TO_OWNING_MU_RTO2_CAPTURE_ONLY',
        'status':status,'expected':expected,'completed':len(results), 'errors':errors,
        'work_count':args.n,'expected_result':args.n*(args.n+1)//2,
        'results':results, 'transport':'native authenticated Queue Fabric XTP wire via owning MU controller',
        'controller_evidence':'MU-local durable RTO2 receipts, collected over sshnode operational plane',
        'limitations':'RTO2 local committed capture; not mirrored RTO2 ACTIVE/SPARE or Job-to-Node allocator lease'}
    (destination/'summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
    print(f'CENTRAL_RESULT {status} {len(results)}/{expected}: {destination / "summary.json"}')
    return 0 if status=='PASS' else 1

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sshnode',default='./sshnode.sh')
    p.add_argument('--controller-script',default='/opt/rexxos/rto2-smoke/bin/mu_controller_run.sh')
    p.add_argument('--run',required=True)
    p.add_argument('--output',required=True)
    p.add_argument('--n',type=int,default=1000)
    p.add_argument('--epoch',type=int,default=1)
    p.add_argument('--timeout',type=int,default=180)
    p.add_argument('--only',nargs='*',default=[])
    p.add_argument('--dry-run',action='store_true')
    args=p.parse_args()
    try:sys.exit(run(args))
    except Exception as e:
        print('RUNNER_REJECTED:',e,file=sys.stderr);sys.exit(2)
