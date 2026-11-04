/* Source-load and payload-shape smoke. Requires Storage + Mesh + Queue Fabric on REXX_PATH. */
::requires "StorageRepairQueue.cls"

req=.StorageReplicaRequirement~new(2,2,2,2)
work=.StorageRepairWork~new("repair-1","sha256:test","INSUFFICIENT_REPLICAS",req,"17","GIT")
p=work~payload
if p["schema"]<>"storage.fabric.repair.work/1" then do; say "FAIL schema"; exit 1; end
if p["repair_id"]<>"repair-1" then do; say "FAIL repair id"; exit 2; end
if p["requirement"]["safe_replicas"]<>2 then do; say "FAIL requirement"; exit 3; end
say "PASS storage durable repair payload"
exit 0
