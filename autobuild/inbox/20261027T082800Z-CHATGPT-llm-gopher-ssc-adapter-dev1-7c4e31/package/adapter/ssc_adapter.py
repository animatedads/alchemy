#!/usr/bin/env python3
"""Finder-authorised LLM Gopher adapter for read-only Semantic Source Control."""
from __future__ import annotations
import json, os, shutil, subprocess, sys
from pathlib import Path

GOPHER_SCHEMA='llm-gopher/0.21'
MACHINE_SCHEMA='semantic.source.control.machine/0.1'
CAP_PREFIX='source.semantic.'
DEFAULT_SPHERE='semantic-source-control'

SCHEMAS={
 'source.semantic.status':{
   'summary':'Read the latest accepted SSC component/lineage/source-level status and semantic counts.',
   'parameters':{'component':{'type':'string','required':True},'repo':{'type':'string','required':True}},
   'result':{'component':'string','lineage':'string','source_level':'string','counts':'object','tracking':'object'},
   'supports':['ssc','read-only','accepted-history']},
 'source.semantic.identify':{
   'summary':'Resolve a stable SSC package/class/method/attribute/constant/external-operation identity.',
   'parameters':{'component':{'type':'string','required':True},'target':{'type':'string','required':True},'repo':{'type':'string','required':True},'level':{'type':'string','required':False}},
   'result':{'component':'string','matches':'SemanticEntity[]'},
   'supports':['ssc','read-only','stable-identity']},
 'source.semantic.compare':{
   'summary':'Compare a working source tree with the latest accepted SSC level without accepting it.',
   'parameters':{'component':{'type':'string','required':True},'path':{'type':'string','required':True},'repo':{'type':'string','required':True}},
   'result':{'semantic_deltas':'SemanticDelta[]','tracking_proposals_pending':'integer'},
   'supports':['ssc','read-only','semantic-diff']},
 'source.semantic.impact':{
   'summary':'Assess known consumer impact for a working candidate against accepted SSC history.',
   'parameters':{'component':{'type':'string','required':True},'path':{'type':'string','required':True},'repo':{'type':'string','required':True},'against':{'type':'string','required':False}},
   'result':{'semantic_delta_count':'integer','impact_findings':'ImpactFinding[]'},
   'supports':['ssc','read-only','impact']},
 'source.semantic.source':{
   'summary':'Read the exact historical method source selected by stable SSC identity.',
   'parameters':{'component':{'type':'string','required':True},'target':{'type':'string','required':True},'repo':{'type':'string','required':True},'level':{'type':'string','required':False}},
   'result':{'source':'string','sha256':'hex'},
   'supports':['ssc','read-only','historical-source']},
 'source.semantic.proposals':{
   'summary':'Read SSC external-operation tracking proposals and recorded decisions without mutating them.',
   'parameters':{'repo':{'type':'string','required':True}},
   'result':{'proposals':'TrackingProposal[]','count':'integer'},
   'supports':['ssc','read-only','external-operations']},
}

MACHINE={
 'source.semantic.status':('status',['component'],[('repo','--repo')]),
 'source.semantic.identify':('identify',['component','target'],[('repo','--repo'),('level','--level')]),
 'source.semantic.compare':('compare',['component','path'],[('repo','--repo')]),
 'source.semantic.impact':('impact',['component','path'],[('repo','--repo'),('against','--against')]),
 'source.semantic.source':('source',['component','target'],[('repo','--repo'),('level','--level')]),
 'source.semantic.proposals':('proposals',[],[('repo','--repo')]),
}

def envelope(tool='OK', operation='OK', result=None, **extra):
    rcmap={'OK':0,'INVALID_REQUEST':2,'UNAVAILABLE':3,'TEMPORARY_FAILURE':4,'PERMISSION_DENIED':5,'IMPLEMENTATION_FAILURE':6,'DEPENDENCY_FAILURE':7,'TIMEOUT':8}
    op_rc=0 if operation in {'OK','FOUND','OPENED','UNCHANGED','CHANGED','REVIEW_REQUIRED','AMBIGUOUS','DESCRIBED'} else (2 if operation=='INVALID_ARGUMENT' else 1)
    out={'schema':GOPHER_SCHEMA,'tool_status':{'rc':rcmap.get(tool,6),'class':tool},'operation_status':{'rc':op_rc,'class':operation},'result':result}
    out.update(extra); return out

def emit(obj): print(json.dumps(obj,indent=2,sort_keys=True))

def resolve_base():
    explicit=os.environ.get('LLM_GOPHER_BASE') or os.environ.get('LLM_GOPHER_EXECUTABLE')
    if explicit and Path(explicit).is_file(): return explicit
    root=os.environ.get('LLM_GOPHER_ROOT')
    if root and Path(root,'gopher').is_file(): return str(Path(root,'gopher'))
    p=shutil.which('gopher')
    return p

def resolve_machine():
    explicit=os.environ.get('SSC_MACHINE')
    if explicit and Path(explicit).is_file(): return explicit
    root=os.environ.get('OOREXX_SEMANTIC_SOURCE_CONTROL_MACHINE_ROOT')
    if root and Path(root,'bin','ssc-machine').is_file(): return str(Path(root,'bin','ssc-machine'))
    return shutil.which('ssc-machine')

def run_json(argv,timeout=120):
    try: cp=subprocess.run(argv,text=True,capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired: return None,None,'timeout'
    try: data=json.loads(cp.stdout)
    except json.JSONDecodeError: return cp,None,'invalid-json'
    return cp,data,None

def split_global(argv):
    global_args=[]; i=0
    while i<len(argv):
        a=argv[i]
        if a in ('--pack','--profile','--role'):
            if i+1>=len(argv): return None,None,envelope('OK','INVALID_ARGUMENT',{'missing':[a]})
            global_args.extend([a,argv[i+1]]); i+=2; continue
        if a=='--version': return global_args,argv[i:],None
        break
    return global_args,argv[i:],None

def parse_kv(items):
    args={}; bad=[]
    for item in items:
        if '=' not in item: bad.append({'value':item,'reason':'expected key=value'}); continue
        k,v=item.split('=',1); args[k]=v
    return args,bad

def validate(cap,args):
    schema=SCHEMAS[cap]; missing=[]
    allowed=set(schema['parameters'])
    for name,spec in schema['parameters'].items():
        if spec.get('required') and not args.get(name): missing.append(name)
    invalid=[{'field':k,'reason':'unknown argument'} for k in args if k not in allowed]
    if missing or invalid: return envelope('OK','INVALID_ARGUMENT',{'capability':cap,'missing':missing,'invalid':invalid,'schema':schema})
    return None

def finder(base,global_args,cap,sphere):
    cp,data,err=run_json([base,*global_args,'find',cap,'--sphere',sphere],30)
    if err=='timeout': return envelope('TIMEOUT','UNKNOWN',None,diagnostics=['Gopher Finder timed out'])
    if err: return envelope('DEPENDENCY_FAILURE','UNKNOWN',None,diagnostics=['Gopher Finder returned invalid JSON'])
    if cp.returncode not in (0,1,2) and data.get('tool_status',{}).get('class')=='OK':
        return envelope('DEPENDENCY_FAILURE','UNKNOWN',None,diagnostics=['Gopher Finder failed rc='+str(cp.returncode)])
    return data

def authorised_proxy(find_result,cap):
    if find_result.get('tool_status',{}).get('class')!='OK': return None
    if find_result.get('operation_status',{}).get('class')!='FOUND': return None
    proxies=(find_result.get('result') or {}).get('proxies') or []
    expected='external.semantic-source-control.machine.'+cap.rsplit('.',1)[-1]
    for p in proxies:
        if p.get('implementation')==expected: return p
    return None

def machine_argv(machine,cap,args):
    cmd,positionals,options=MACHINE[cap]
    out=[machine,cmd]
    out.extend(args[k] for k in positionals)
    for key,flag in options:
        if args.get(key) not in (None,''): out.extend([flag,args[key]])
    return out

def exec_semantic(base,global_args,cap,items):
    args,bad=parse_kv(items)
    if bad:return envelope('OK','INVALID_ARGUMENT',{'capability':cap,'invalid':bad,'schema':SCHEMAS[cap]})
    sphere=args.pop('sphere',DEFAULT_SPHERE)
    v=validate(cap,args)
    if v:return v
    f=finder(base,global_args,cap,sphere)
    proxy=authorised_proxy(f,cap)
    if proxy is None:
        if f.get('tool_status',{}).get('class')!='OK': return f
        return envelope('OK','NOT_FOUND',{'capability':cap,'sphere':sphere,'reason':'no authorised SSC machine service'})
    machine=resolve_machine()
    if not machine:return envelope('UNAVAILABLE','UNKNOWN',None,diagnostics=['ssc-machine executable unavailable'])
    cp,data,err=run_json(machine_argv(machine,cap,args),120)
    if err=='timeout':return envelope('TIMEOUT','UNKNOWN',None,diagnostics=['SSC machine protocol timed out'])
    if err:return envelope('DEPENDENCY_FAILURE','UNKNOWN',None,diagnostics=['SSC machine protocol returned invalid JSON'])
    if data.get('schema')!=MACHINE_SCHEMA:return envelope('DEPENDENCY_FAILURE','UNKNOWN',None,diagnostics=['unexpected SSC machine schema'])
    tool=data.get('tool_status','IMPLEMENTATION_FAILURE'); op=data.get('operation_status','UNKNOWN')
    out=envelope(tool,op,data.get('result'),diagnostics=data.get('diagnostics',[]))
    out['service_proxy']=proxy
    out['route']={'requested_capability':cap,'service':proxy.get('service'),'implementation':proxy.get('implementation'),'fallback_depth':0,'attempts':[{'service':proxy.get('service'),'implementation':proxy.get('implementation'),'tool_status':tool}]}
    out['evidence']={'machine_schema':MACHINE_SCHEMA,'machine_executable':machine}
    return out

def describe_semantic(base,global_args,cap,sphere):
    f=finder(base,global_args,cap,sphere)
    services=[]
    if f.get('operation_status',{}).get('class')=='FOUND': services=(f.get('result') or {}).get('proxies') or []
    result=dict(SCHEMAS[cap]); result.update({'id':cap,'available':bool(services),'services':services,'invocation':{'low_level':'gopher-ssc exec '+cap+' key=value ...'}})
    return envelope('OK','OPENED',result)

def enrich_context(obj):
    if obj.get('tool_status',{}).get('class')!='OK':return obj
    result=obj.get('result') or {}
    caps=result.get('capabilities') or []
    for item in caps:
        schema=SCHEMAS.get(item.get('id'))
        if not schema:continue
        item['summary']=schema['summary']
        item['required']=[k for k,v in schema['parameters'].items() if v.get('required')]
        item['supports']=schema.get('supports',[])
        if 'parameters' in item:item['parameters']=schema['parameters']; item['examples']=schema.get('examples',[])
    return obj

def main(argv):
    base=resolve_base()
    if not base:
        emit(envelope('UNAVAILABLE','UNKNOWN',None,diagnostics=['base gopher executable unavailable']));return 3
    global_args,rest,err=split_global(argv)
    if err:emit(err);return 2
    if not rest:
        cp=subprocess.run([base,*argv]);return cp.returncode
    cmd=rest[0]
    if cmd=='exec' and len(rest)>=2 and rest[1] in SCHEMAS:
        out=exec_semantic(base,global_args,rest[1],rest[2:]);emit(out)
        return out['tool_status']['rc'] if out['tool_status']['class']!='OK' else (2 if out['operation_status']['class']=='INVALID_ARGUMENT' else 0)
    if cmd=='describe' and len(rest)>=2 and rest[1] in SCHEMAS:
        sphere=DEFAULT_SPHERE
        if '--sphere' in rest[2:]:
            j=rest.index('--sphere'); sphere=rest[j+1] if j+1<len(rest) else DEFAULT_SPHERE
        out=describe_semantic(base,global_args,rest[1],sphere);emit(out);return 0
    if cmd=='context' and len(rest)>=2:
        cp,data,e=run_json([base,*argv],60)
        if e or data is None:
            sys.stdout.write(cp.stdout if cp else ''); sys.stderr.write(cp.stderr if cp else ''); return cp.returncode if cp else 7
        emit(enrich_context(data));return cp.returncode
    cp=subprocess.run([base,*argv]);return cp.returncode

if __name__=='__main__': raise SystemExit(main(sys.argv[1:]))
