from pathlib import Path
p=Path(__file__).resolve().parents[1]/'src'/'StorageRepairQueue.cls'
s=p.read_text()
required=[
 'storage.fabric.repair.queue/0.1','storage.fabric.repair.work/1',
 '"PERMANENT"','options["persistent"]=.true','options["correlationId"]=work~repairId',
 'policy~assess(object,requirement)','if before~satisfied then do',
 'planner~repair(object,requirement,payload)','if \\after~satisfied',
 'instrumentation~repairRequired','instrumentation~repairSatisfied',
 '::requires "ObjectQueueFabric.cls"'
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('FAIL missing: '+repr(missing))
for forbidden in ['Storage identity == host pathname','password','PAT=','FkKsHJ']:
    if forbidden in s:
        raise SystemExit('FAIL forbidden content: '+forbidden)
print('PASS durable Storage repair queue static contract')
