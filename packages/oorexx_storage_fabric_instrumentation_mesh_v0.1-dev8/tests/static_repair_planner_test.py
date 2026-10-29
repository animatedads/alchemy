from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'src'/'StorageRepairPlanner.cls').read_text()
required=[
 '::class StorageRepairDestinationPlanner public',
 '::class StorageGitRepairDestination public',
 'policy~assess(shadow,requirement)',
 'if gain<=0 then iterate',
 'sourceResolver~resolve(object,payload)',
 'if \\source~verified then return',
 'if \\location~countsAsDurable then return',
 'object~addLocation(location)',
 'provider~store(object~ref,sourcePath,observedAt)',
 'gitStoreCompleted',
]
missing=[x for x in required if x not in p]
if missing: raise SystemExit('FAIL repair planner markers missing: '+repr(missing))
forbidden=['JobNode','Job-to-Node','62801','protocol 36','0x817D','provider~repositoryUrl~pos("azure")']
found=[x for x in forbidden if x in p]
if found: raise SystemExit('FAIL planner acquired forbidden transport/placement knowledge: '+repr(found))
print('PASS Storage repair destination planner policy/provider boundary')
