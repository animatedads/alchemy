#!/usr/bin/env python3
"""Controller/operator-plane orchestration; MI work and authenticated results use native XTP on owning MU."""
import argparse,csv,hashlib,json,os,pathlib,re,shlex,subprocess,sys
from controller_commit import check
HOSTS=['a','b','c','d','e','i','j','k','f','h']
TARGETS=[(2*i+j+1,'ed209'+host,'MU-ED209'+host.upper(),f'MN{j+1}-ED209{host.upper()}')
 for i,host in enumerate(HOSTS) for j in range(2)]
FIELDS=['route','host','mu','mi','status','value','rto2_sequence','rto2_epoch','receipt_sha256','committed_at_utc']

def verified(receipt,route,host,mu,mi,run_id,n,epoch):
    value=check(receipt,run_id,mi,mu,n,epoch)
    if receipt.get('controller_commit')!='DURABLE_LOCAL_RECEIPT':raise ValueError('controller receipt not durable')
    digest=receipt.get('receipt_sha256','')
    if not re.fullmatch('[0-9a-f]{64}',digest):raise ValueError('missing digest')
    canonical=json.dumps({k:v for k,v in receipt.items()
                          if k not in ('controller_commit','receipt_sha256','committed_at_utc')},
                         sort_keys=True,separators=(',',':')).encode()
    if hashlib.sha256(canonical).hexdigest()!=digest:raise ValueError('controller receipt digest mismatch')
    return dict(route=route,host=host,mu=mu,mi=mi,status='PASS',value=value,
       rto2_sequence=receipt['rto2']['committed_sequence'],rto2_epoch=epoch,
       receipt_sha256=digest,committed_at_utc=receipt['committed_at_utc'])

def execute(args):
    if not re.fullmatch('[A-Za-z0-9._-]{1,80}',args.run):raise ValueError('bad run identifier')
    if not 1<=args.n<=1000 or args.epoch<1:raise ValueError('bad work/epoch')
    rows=[x for x in TARGETS if not args.only or x[1] in args.only]
    if set(args.only)-{x[1] for x in TARGETS}:raise ValueError('unknown host')
    if args.dry_run:
        for route,host,mu,mi in rows:print(f'PLAN route={route} controller={mu} host={host} MI={mi} n={args.n}')
        return 0
    if not pathlib.Path(args.sshnode).is_file():raise ValueError('missing operator sshnode.sh')
    output=pathlib.Path(args.output);output.mkdir(parents=True,exist_ok=False);os.chmod(output,0o700)
    successes=[];failures=[]
    for route,host,mu,mi in rows:
        cmd=' '.join(shlex.quote(x) for x in ['bash',args.controller_script,args.run,mi,str(args.n)])
        try:
            p=subprocess.run([args.sshnode,host,cmd],capture_output=True,text=True,timeout=args.timeout)
            if p.returncode:raise ValueError('owning MU controller rc='+str(p.returncode))
            receipts=[x for x in p.stdout.splitlines() if x.strip().startswith('{')]
            if len(receipts)!=1:raise ValueError('expected exactly one controller receipt')
            result=verified(json.loads(receipts[0]),route,host,mu,mi,args.run,args.n,args.epoch)
            successes.append(result);print('PASS',mi,result['value'],flush=True)
        except Exception as exc:
            failures.append(dict(route=route,mi=mi,controller=mu,reason=str(exc)))
            print('FAIL',mi,str(exc),file=sys.stderr,flush=True)
    successes.sort(key=lambda x:x['route'])
    for filename,data in [('results_by_route.csv',successes),('results_by_value.csv',sorted(successes,key=lambda r:(r['value'],r['route'])))]:
        with (output/filename).open('w',newline='') as fh:
            w=csv.DictWriter(fh,fieldnames=FIELDS);w.writeheader();w.writerows(data)
    expected=len(rows)
    ok=not failures and len(successes)==expected and len({x['mi'] for x in successes})==expected
    summary=dict(schema='ed209.rto2.mesh-sort.summary/1',run_id=args.run,scope='FULL_20_MI' if not args.only else 'SUBSET_NOT_FULL_ESTATE',
      status='PASS' if ok else 'FAIL',expected=expected,completed=len(successes),errors=failures,results=successes,
      qualification_boundary='LOCAL_MI_EXECUTION_TO_OWNING_MU_RTO2_CAPTURE_ONLY',
      transport='native authenticated Queue Fabric/XTP via owning MU; SSH operator management only',
      limitation='no mirrored replay, dev25 service-first deployment, or Job-to-Node lease claim')
    (output/'summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
    return 0 if ok else 1
if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--sshnode',default='./sshnode.sh');p.add_argument('--controller-script',default='/opt/rexxos/rto2-smoke/bin/mu_controller_run.sh')
    p.add_argument('--run',required=True);p.add_argument('--output',required=True);p.add_argument('--n',type=int,default=1000)
    p.add_argument('--epoch',type=int,default=1);p.add_argument('--timeout',type=int,default=180)
    p.add_argument('--only',nargs='*',default=[]);p.add_argument('--dry-run',action='store_true')
    a=p.parse_args()
    try:sys.exit(execute(a))
    except Exception as e:print('RUNNER_REJECTED',str(e),file=sys.stderr);sys.exit(2)
