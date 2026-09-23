/* StorageEvacuationQueueRexx.cls - QueueRexx v0.1-dev12 binding.
 * QueueRexx owns scheduling/retry; evacuation manifest remains correctness authority. */
::class EvacQueueJobClass public
::constant HIGH "EVAC_HIGH"
::constant NORMAL "EVAC_NORMAL"
::constant BULK "EVAC_BULK"
::constant RESCAN "EVAC_RESCAN"
::constant VERIFY "EVAC_VERIFY"
::constant FINAL "EVAC_FINAL"

::class EvacQueuePolicyGate public subclass QueueOperationPolicyGate
::method assessSubmit
  use strict arg request
  if left(request~jobClass,5)="EVAC_" then return .QueuePolicyVerdict~allow
  return .QueuePolicyVerdict~deny("EVAC_CLASS_REQUIRED","evacuation queue binding admits EVAC_* classes only")
::method assessExecution
  use strict arg record
  if left(record~jobClass,5)="EVAC_" then return .QueuePolicyVerdict~allow
  return .QueuePolicyVerdict~deny("EVAC_CLASS_REQUIRED","evacuation queue binding executes EVAC_* classes only")

::class EvacQueueWorkUnit public
::attribute name get
::attribute command get
::attribute priority get
::attribute jobClass get
::method init
  expose name command priority jobClass
  use strict arg nameArg, commandArg, priorityArg=10, classArg=(.EvacQueueJobClass~NORMAL)
  name=nameArg~string; command=commandArg; priority=priorityArg+0; jobClass=classArg~string
::method asSubmitRequest
  expose name command priority jobClass
  return .QueueSubmitRequest~new(name,command,priority,jobClass,.QueueRunnerKind~DIRECT)

::class EvacQueueRexxDispatcher public
::attribute service get
::method init
  expose service
  use strict arg queueRoot
  service=.QueueSubmitService~new(queueRoot,.EvacQueuePolicyGate~new)
::method submit
  expose service
  use strict arg workUnit
  return service~submit(workUnit~asSubmitRequest)
::method submitMany
  use strict arg units
  out=.Array~new
  do u over units; out~append(self~submit(u)); end
  return out

::requires "vendor/queuerexx/QueueRexxOperations.cls"

/* dev7: manifest-derived durable semantic work. */
::class EvacWorkIntent public
::attribute intentId get
::attribute jobClass get
::attribute paths get
::attribute totalBytes get
::attribute state
::method init
  expose intentId jobClass paths totalBytes state
  use strict arg idArg,classArg,pathsArg,bytesArg
  intentId=idArg~string; jobClass=classArg~string; paths=pathsArg; totalBytes=bytesArg+0; state="PLANNED"

::class EvacManifestPlanner public
::method plan
  use strict arg generation,maxBatchBytes=67108864,maxBatchItems=512,largeObjectBytes=1073741824
  out=.Array~new; buckets=.directory~new; bucketBytes=.directory~new
  do p over generation~entries
    e=generation~entries[p]
    if e~objectState="EXCLUDED" then iterate
    if e~verifiedCurrentCount>0 then iterate
    if e~metadata~type<>"regular file" then iterate
    sz=e~metadata~sizeBytes+0
    if sz>=largeObjectBytes then do
      a=.Array~new; a~append(e~relativePath)
      out~append(.EvacWorkIntent~new(self~intentId(generation,e~relativePath,.EvacQueueJobClass~BULK),.EvacQueueJobClass~BULK,a,sz))
      iterate
    end
    cls=.EvacQueueJobClass~NORMAL
    if sz<=1048576 then cls=.EvacQueueJobClass~HIGH
    if \buckets~hasIndex(cls) then do; buckets[cls]=.Array~new; bucketBytes[cls]=0; end
    if buckets[cls]~items>0 & (buckets[cls]~items>=maxBatchItems | bucketBytes[cls]+sz>maxBatchBytes) then do
      out~append(.EvacWorkIntent~new(self~batchId(generation,cls,buckets[cls]),cls,buckets[cls],bucketBytes[cls]))
      buckets[cls]=.Array~new; bucketBytes[cls]=0
    end
    buckets[cls]~append(e~relativePath); bucketBytes[cls]+=sz
  end
  do cls over buckets
    if buckets[cls]~items>0 then out~append(.EvacWorkIntent~new(self~batchId(generation,cls,buckets[cls]),cls,buckets[cls],bucketBytes[cls]))
  end
  return out
::method intentId private
  use arg generation,pathArg,classArg
  return "evac:"||generation~number||":"||classArg||":"||pathArg
::method batchId private
  use arg generation,classArg,paths
  first=paths[1]; last=paths[paths~items]
  return "evac:"||generation~number||":"||classArg||":"||paths~items||":"||first||":"||last

::class EvacCompletionApplier public
::method applyVerified
  use strict arg generation,pathArg,replica
  if \generation~entries~hasIndex(pathArg) then return .false
  e=generation~entries[pathArg]
  if e~replicas~hasIndex(replica~replicaId) then do
    old=e~replicas[replica~replicaId]
    if old~state="VERIFIED_CURRENT" then return .true
  end
  e~addReplica(replica)
  return replica~state="VERIFIED_CURRENT"
