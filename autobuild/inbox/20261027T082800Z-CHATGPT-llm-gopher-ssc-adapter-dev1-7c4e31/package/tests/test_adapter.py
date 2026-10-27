#!/usr/bin/env python3
import json, os, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as td:
    t=pathlib.Path(td); log=t/'machine.log'; allow=t/'allow'
    allow.write_text('yes')
    g=t/'gopher'; m=t/'ssc-machine'
    g.write_text('''#!/usr/bin/env python3
import json,sys,os
args=sys.argv[1:]
if "find" in args:
 c=args[args.index("find")+1]
 if os.environ.get("DENY")=="1": o={"schema":"llm-gopher/0.21","tool_status":{"rc":0,"class":"OK"},"operation_status":{"rc":1,"class":"NOT_FOUND"},"result":{"proxies":[]}}
 else: o={"schema":"llm-gopher/0.21","tool_status":{"rc":0,"class":"OK"},"operation_status":{"rc":0,"class":"FOUND"},"result":{"proxies":[{"service":"ssc.machine."+c.rsplit(".",1)[-1],"implementation":"external.semantic-source-control.machine."+c.rsplit(".",1)[-1],"capability":c}]}}
elif "context" in args:
 o={"schema":"llm-gopher/0.21","tool_status":{"rc":0,"class":"OK"},"operation_status":{"rc":0,"class":"OPENED"},"result":{"capabilities":[{"id":"source.semantic.status","summary":None,"required":[],"supports":[]}]}}
else: o={"schema":"llm-gopher/0.21","tool_status":{"rc":0,"class":"OK"},"operation_status":{"rc":0,"class":"OK"},"result":{}}
print(json.dumps(o))
''')
    m.write_text('''#!/usr/bin/env python3
import json,sys,os
open(os.environ["MLOG"],"w").write("\\n".join(sys.argv[1:]))
print(json.dumps({"schema":"semantic.source.control.machine/0.1","tool_status":"OK","operation_status":"FOUND","operation":"status","result":{"component":"Demo"},"diagnostics":[]}))
''')
    g.chmod(0o755);m.chmod(0o755)
    env=os.environ.copy();env.update(LLM_GOPHER_BASE=str(g),SSC_MACHINE=str(m),MLOG=str(log))
    def run(*a,envx=None):
        e=env.copy(); e.update(envx or {})
        return subprocess.run([str(ROOT/'bin/gopher-ssc'),*a],text=True,capture_output=True,env=e)
    p=run('exec','source.semantic.status','component=Demo','repo=/tmp/repo','sphere=semantic-source-control')
    assert p.returncode==0,p.stderr+p.stdout
    o=json.loads(p.stdout);assert o['operation_status']['class']=='FOUND';assert o['route']['implementation']=='external.semantic-source-control.machine.status'
    assert log.read_text().splitlines()==['status','Demo','--repo','/tmp/repo']
    p=run('describe','source.semantic.status','--sphere','semantic-source-control');o=json.loads(p.stdout);assert o['result']['available'] is True
    p=run('context','semantic-source-control');o=json.loads(p.stdout);c=o['result']['capabilities'][0];assert c['summary'] and c['required']==['component','repo']
    log.unlink()
    p=run('exec','source.semantic.status','component=Demo','repo=/tmp/repo',envx={'DENY':'1'});o=json.loads(p.stdout);assert o['operation_status']['class']=='NOT_FOUND';assert not log.exists()
    p=run('exec','source.semantic.status','component=Demo');o=json.loads(p.stdout);assert o['operation_status']['class']=='INVALID_ARGUMENT';assert 'repo' in o['result']['missing']
print('PASS test_adapter')
