from pathlib import Path
s=(Path(__file__).parents[1]/'src'/'StorageRepairQueue.cls').read_text()
required=[
 '::class StorageReplicaRepairReconciler public',
 'manager~catalogue~byProvider(providerId)',
 'assessment=policy~assess(object,requirement)',
 'if assessment~satisfied then do',
 'binding~submit(work)',
 'meta["trigger"]="PROVIDER_TRANSITION"',
 'requirement~requiredReplicas',
 'requirement~distinctVendors',
 'requirement~distinctSites',
 'requirement~distinctFailureDomains',
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('FAIL missing: '+repr(missing))
legacy=['requiredSafeReplicas','requiredDistinctVendors','requiredDistinctSites','requiredDistinctFailureDomains']
found=[x for x in legacy if x in s]
if found:
    raise SystemExit('FAIL legacy requirement API remains: '+repr(found))
print('PASS dev23 replica requirement compatibility and topology repair reconciliation')
