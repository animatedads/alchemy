from pathlib import Path
root=Path(__file__).resolve().parents[1]
repair=(root/'src/StorageRepairQueue.cls').read_text()
mesh=(root/'src/StorageInstrumentationMesh.cls').read_text()
required=['REPLICA_REQUIREMENT_MISSING','fallbackRequirementArg=.nil','policyMissing+=1','::attribute policyMissing get','storage.replica.objects.policy_missing']
missing=[x for x in required if x not in repair+mesh]
if missing: raise SystemExit('FAIL missing fail-closed policy markers: '+repr(missing))
forbidden=['if payload["requirement"]==.nil then return .StorageReplicaRequirement~new(1)','return .StorageReplicaRequirement~new(1)']
found=[x for x in forbidden if x in repair or x in mesh]
if found: raise SystemExit('FAIL implicit one-replica fallback remains: '+repr(found))
print('PASS missing replica policy fails closed; explicit fallback only')
