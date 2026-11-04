/* InstrumentationMesh.cls
 * Estate-wide operational instrumentation language and mesh service.
 * API: instrumentation.mesh/0.1
 *
 * Instrumentation owns observations, vocabulary, query semantics and the
 * management request envelope. Queue Fabric is the preferred carrier, but is
 * deliberately not an authority dependency of this class file.
 */

::class InstrumentationBuild public
::constant VERSION "0.1-dev3"
::constant API "instrumentation.mesh/0.1"

::class InstrumentationContract public
::constant API "instrumentation.mesh/0.1"
::constant CAPABILITY_SCHEMA "instrumentation.capability/1"
::constant SAMPLE_SCHEMA "instrumentation.sample/1"
::constant SNAPSHOT_SCHEMA "instrumentation.snapshot/1"
::constant QUERY_SCHEMA "instrumentation.query/1"
::constant REPLY_SCHEMA "instrumentation.reply/1"
::constant COMMAND_SCHEMA "instrumentation.command/1"
::constant COMMAND_RESULT_SCHEMA "instrumentation.command-result/1"
::constant PROGRESS_SCHEMA "instrumentation.progress/1"
::constant PUBLICATION_SCHEMA "instrumentation.publication/1"
::constant PUBLICATION_RECEIPT_SCHEMA "instrumentation.publication-receipt/1"
::constant SECURITY_DOMAIN "MANAGEMENT"
::constant QUEUE_SERVICE_ROUTE "instrumentation.mesh/0.1"

::class InstrumentationMetricKind public
::constant COUNTER "COUNTER"
::constant GAUGE "GAUGE"
::constant RATE "RATE"
::constant STATE "STATE"
::constant PROGRESS "PROGRESS"
::constant DISTRIBUTION "DISTRIBUTION"

::class InstrumentationHealth public
::constant UNKNOWN "UNKNOWN"
::constant STARTING "STARTING"
::constant HEALTHY "HEALTHY"
::constant DEGRADED "DEGRADED"
::constant FAILED "FAILED"
::constant STOPPING "STOPPING"
::constant STOPPED "STOPPED"

::class InstrumentationVocabulary public
::constant SERVICE_STATE "service.state"
::constant SERVICE_UPTIME_SECONDS "service.uptime.seconds"
::constant REQUEST_ACCEPTED_TOTAL "request.accepted.total"
::constant REQUEST_INFLIGHT "request.inflight"
::constant REQUEST_COMPLETED_TOTAL "request.completed.total"
::constant REQUEST_FAILED_TOTAL "request.failed.total"
::constant REQUEST_REJECTED_TOTAL "request.rejected.total"
::constant THROUGHPUT_REQUESTS_PER_SECOND "throughput.requests_per_second"
::constant BYTES_IN_TOTAL "io.bytes.in.total"
::constant BYTES_OUT_TOTAL "io.bytes.out.total"
::constant BYTES_IN_PER_SECOND "io.bytes.in_per_second"
::constant BYTES_OUT_PER_SECOND "io.bytes.out_per_second"
::constant MEMORY_RESIDENT_BYTES "memory.resident.bytes"
::constant MEMORY_MANAGED_BYTES "memory.managed.bytes"
::constant QUEUE_DEPTH "queue.depth"
::constant QUEUE_OLDEST_AGE_SECONDS "queue.oldest_age.seconds"
::constant OPERATION_PROGRESS "operation.progress"
::constant QUEUE_COUNT "queue.count"
::constant QUEUE_READY_DEPTH "queue.ready.depth"
::constant QUEUE_INFLIGHT_DEPTH "queue.inflight.depth"
::constant QUEUE_TRAFFIC_EVENTS_TOTAL "queue.traffic.events.total"
::constant QUEUE_UOW_ACTIVE "queue.uow.active"
::constant QUEUE_TRANSFER_RECEIPTS_TOTAL "queue.transfer.receipts.total"
::constant QUEUE_CHANNEL_SENT_TOTAL "queue.channel.sent.total"
::constant QUEUE_CHANNEL_RECEIVED_TOTAL "queue.channel.received.total"
::constant QUEUE_CHANNEL_REJECTED_TOTAL "queue.channel.rejected.total"
::constant MEMORY_PROVIDER_COUNT "memory.provider.count"
::constant MEMORY_CAPACITY_BYTES "memory.capacity.bytes"
::constant MEMORY_COMMITTED_BYTES "memory.committed.bytes"
::constant MEMORY_AVAILABLE_BYTES "memory.available.bytes"
::constant STORAGE_CATALOGUE_OBJECTS "storage.catalogue.objects"
::constant STORAGE_POOL_COUNT "storage.pool.count"
::constant STORAGE_CAPACITY_BYTES "storage.capacity.bytes"
::constant STORAGE_FREE_BYTES "storage.free.bytes"
::constant STORAGE_WORKSPACE_AVAILABLE_BYTES "storage.workspace.available.bytes"
::constant STORAGE_WORKSPACE_RESERVED_BYTES "storage.workspace.reserved.bytes"
::constant STORAGE_ALLOCATION_COUNT "storage.allocation.count"
::constant CPU_UTILISATION_PERCENT "cpu.utilisation.percent"
::constant NETWORK_THROUGHPUT_BYTES_PER_SECOND "network.throughput.bytes_per_second"
::constant NETWORK_RTT_MILLISECONDS "network.rtt.milliseconds"

/* ====================================================================== */
::class InstrumentationCodec public
::method value class
  use strict arg directory,key,defaultValue=""
  if directory==.nil then return defaultValue
  v=directory[key]
  if v==.nil then return defaultValue
  return v

::method whole class
  use strict arg directory,key,defaultValue=0
  v=self~value(directory,key,defaultValue)
  if \datatype(v,"W") then return defaultValue
  return v

::method copyDirectory class
  use strict arg source=.nil
  d=.directory~new
  if source<>.nil then do k over source; d[k]=self~copyValue(source[k]); end
  return d

::method copyValue class
  use strict arg value
  if value==.nil then return .nil
  if value~isA(.Directory) then return self~copyDirectory(value)
  if value~isA(.Array) then do
    a=.array~new
    do item over value; a~append(self~copyValue(item)); end
    return a
  end
  return value

::method identityKey class
  use strict arg identity
  return self~value(identity,"estate_id","")||"1F"x||self~value(identity,"service_id","")||"1F"x||self~value(identity,"instance_id","")||"1F"x||self~value(identity,"node_id","")

::method semanticRef class
  use strict arg identity
  estate=self~value(identity,"estate_id","")~string
  service=self~value(identity,"service_id","")~string
  instance=self~value(identity,"instance_id","")~string
  node=self~value(identity,"node_id","")~string
  return "instrumentation://"||estate||"/"||service||"/"||instance||"@"||node

::method identity class
  use strict arg estateId,serviceId,instanceId,nodeId,miId="",serviceKind="",location=.nil
  d=.directory~new
  d["estate_id"]=estateId~string
  d["service_id"]=serviceId~string
  d["instance_id"]=instanceId~string
  d["node_id"]=nodeId~string
  d["mi_id"]=miId~string
  d["service_kind"]=serviceKind~string
  d["location"]=self~copyDirectory(location)
  d["semantic_ref"]=self~semanticRef(d)
  return d

::method capability class
  use strict arg identity,operations=.nil,metricNames=.nil,commandNames=.nil
  d=.directory~new
  d["schema"]=.InstrumentationContract~CAPABILITY_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["identity"]=identity
  if operations==.nil then operations=.array~new
  if metricNames==.nil then metricNames=.array~new
  if commandNames==.nil then commandNames=.array~new
  d["operations"]=operations
  d["metrics"]=metricNames
  d["commands"]=commandNames
  return d

::method sample class
  use strict arg name,kind,unit,value,observedAt="",dimensions=.nil,intervalStart="",intervalEnd=""
  d=.directory~new
  d["schema"]=.InstrumentationContract~SAMPLE_SCHEMA
  d["name"]=name~string
  d["kind"]=kind~string~upper
  d["unit"]=unit~string
  d["value"]=value
  d["observed_at"]=observedAt~string
  d["interval_start"]=intervalStart~string
  d["interval_end"]=intervalEnd~string
  d["dimensions"]=self~copyDirectory(dimensions)
  return d

::method progress class
  use strict arg operationId,phase,current,total,unit="items",observedAt="",detail=""
  d=.directory~new
  d["schema"]=.InstrumentationContract~PROGRESS_SCHEMA
  d["operation_id"]=operationId~string
  d["phase"]=phase~string
  d["current"]=current
  d["total"]=total
  d["unit"]=unit~string
  d["observed_at"]=observedAt~string
  d["detail"]=detail~string
  if total>0 then d["fraction"]=current/total
  else d["fraction"]=0
  return d

::method snapshot class
  use strict arg identity,health,samples,observedAt="",progressItems=.nil,sequence=0
  d=.directory~new
  d["schema"]=.InstrumentationContract~SNAPSHOT_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["identity"]=self~copyDirectory(identity)
  d["semantic_ref"]=self~semanticRef(identity)
  d["health"]=health~string~upper
  d["observed_at"]=observedAt~string
  d["sequence"]=sequence
  d["samples"]=self~copyValue(samples)
  if progressItems==.nil then progressItems=.array~new
  d["progress"]=self~copyValue(progressItems)
  return d

::method query class
  use strict arg requestId,selector=.nil,metricNames=.nil,since="",until="",windowSeconds=0,mode="HISTORY",limit=0
  d=.directory~new
  d["schema"]=.InstrumentationContract~QUERY_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["request_id"]=requestId~string
  d["selector"]=self~copyDirectory(selector)
  if metricNames==.nil then metricNames=.array~new
  d["metrics"]=self~copyValue(metricNames)
  d["since"]=since~string
  d["until"]=until~string
  d["window_seconds"]=windowSeconds
  d["mode"]=mode~string~upper
  d["limit"]=limit
  return d

::method reply class
  use strict arg request,status,payload=.nil,code=""
  d=.directory~new
  d["schema"]=.InstrumentationContract~REPLY_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["request_id"]=self~value(request,"request_id","")
  d["status"]=status~string~upper
  d["code"]=code~string
  if payload<>.nil then d["payload"]=payload
  return d

::method command class
  use strict arg commandId,target,operation,args=.nil,issuedAt="",authorityRef=""
  d=.directory~new
  d["schema"]=.InstrumentationContract~COMMAND_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["command_id"]=commandId~string
  d["target"]=self~copyDirectory(target)
  d["operation"]=operation~string
  d["args"]=self~copyDirectory(args)
  d["issued_at"]=issuedAt~string
  d["authority_ref"]=authorityRef~string
  return d

::method commandResult class
  use strict arg command,status,code="",detail="",payload=.nil
  d=.directory~new
  d["schema"]=.InstrumentationContract~COMMAND_RESULT_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["command_id"]=self~value(command,"command_id","")
  d["status"]=status~string~upper
  d["code"]=code~string
  d["detail"]=detail~string
  if payload<>.nil then d["payload"]=self~copyValue(payload)
  return d

::method publication class
  use strict arg publicationId,publisherId,sequence,snapshots,observedAt=""
  d=.directory~new
  d["schema"]=.InstrumentationContract~PUBLICATION_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["publication_id"]=publicationId~string
  d["publisher_id"]=publisherId~string
  d["sequence"]=sequence
  d["observed_at"]=observedAt~string
  d["snapshots"]=self~copyValue(snapshots)
  return d

::method publicationReceipt class
  use strict arg publication,status,code="",detail="",accepted=0
  d=.directory~new
  d["schema"]=.InstrumentationContract~PUBLICATION_RECEIPT_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["publication_id"]=self~value(publication,"publication_id","")
  d["publisher_id"]=self~value(publication,"publisher_id","")
  d["sequence"]=self~value(publication,"sequence",0)
  d["status"]=status~string~upper
  d["code"]=code~string
  d["detail"]=detail~string
  d["accepted"]=accepted
  return d

/* ====================================================================== */
/* Mutable counters are kept inside a service-local emitter. Snapshot output
 * is a newly built object graph so callers cannot mutate authoritative state. */
::class InstrumentationEmitter public
::method init
  expose identity health counters gauges units kinds dimensions progresses sequence
  use strict arg identityArg
  identity=identityArg
  health=.InstrumentationHealth~STARTING
  counters=.directory~new; gauges=.directory~new; units=.directory~new
  kinds=.directory~new; dimensions=.directory~new; progresses=.directory~new
  sequence=0

::method setHealth
  expose health
  use strict arg healthArg
  health=healthArg~string~upper
  return self

::method counterAdd
  expose counters units kinds dimensions
  use strict arg name,delta=1,unit="count",dims=.nil
  old=counters[name]
  if old==.nil then old=0
  counters[name]=old+delta
  units[name]=unit~string; kinds[name]=.InstrumentationMetricKind~COUNTER
  dimensions[name]=.InstrumentationCodec~copyDirectory(dims)
  return counters[name]

::method gaugeSet
  expose gauges units kinds dimensions
  use strict arg name,value,unit="count",dims=.nil,kind=""
  if kind="" then kind=.InstrumentationMetricKind~GAUGE
  gauges[name]=value
  units[name]=unit~string; kinds[name]=kind~string~upper
  dimensions[name]=.InstrumentationCodec~copyDirectory(dims)
  return value

::method requestAccepted
  self~counterAdd(.InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL,1)
  self~gaugeSet(.InstrumentationVocabulary~REQUEST_INFLIGHT,self~gaugeValue(.InstrumentationVocabulary~REQUEST_INFLIGHT)+1)
  return self
::method requestCompleted
  self~counterAdd(.InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL,1)
  n=self~gaugeValue(.InstrumentationVocabulary~REQUEST_INFLIGHT)-1; if n<0 then n=0
  self~gaugeSet(.InstrumentationVocabulary~REQUEST_INFLIGHT,n)
  return self
::method requestFailed
  self~counterAdd(.InstrumentationVocabulary~REQUEST_FAILED_TOTAL,1)
  n=self~gaugeValue(.InstrumentationVocabulary~REQUEST_INFLIGHT)-1; if n<0 then n=0
  self~gaugeSet(.InstrumentationVocabulary~REQUEST_INFLIGHT,n)
  return self
::method requestRejected
  self~counterAdd(.InstrumentationVocabulary~REQUEST_REJECTED_TOTAL,1)
  return self
::method bytesIn
  use strict arg bytes
  self~counterAdd(.InstrumentationVocabulary~BYTES_IN_TOTAL,bytes,"bytes")
  return self
::method bytesOut
  use strict arg bytes
  self~counterAdd(.InstrumentationVocabulary~BYTES_OUT_TOTAL,bytes,"bytes")
  return self
::method memoryResident
  use strict arg bytes
  self~gaugeSet(.InstrumentationVocabulary~MEMORY_RESIDENT_BYTES,bytes,"bytes")
  return self
::method progress
  expose progresses
  use strict arg operationId,phase,current,total,unit="items",observedAt="",detail=""
  progresses[operationId~string]=.InstrumentationCodec~progress(operationId,phase,current,total,unit,observedAt,detail)
  return self
::method clearProgress
  expose progresses
  use strict arg operationId
  if progresses[operationId~string]<>.nil then progresses~remove(operationId~string)
  return self
::method gaugeValue
  expose gauges
  use strict arg name
  v=gauges[name]; if v==.nil then return 0
  return v
::method snapshot
  expose identity health counters gauges units kinds dimensions progresses sequence
  use strict arg observedAt=""
  sequence+=1
  samples=.array~new
  do name over counters
    samples~append(.InstrumentationCodec~sample(name,kinds[name],units[name],counters[name],observedAt,dimensions[name]))
  end
  do name over gauges
    samples~append(.InstrumentationCodec~sample(name,kinds[name],units[name],gauges[name],observedAt,dimensions[name]))
  end
  progressItems=.array~new
  do key over progresses; progressItems~append(.InstrumentationCodec~copyDirectory(progresses[key])); end
  return .InstrumentationCodec~snapshot(.InstrumentationCodec~copyDirectory(identity),health,samples,observedAt,progressItems,sequence)

/* ====================================================================== */
::class InstrumentationRegistry public
::method init
  expose sources
  sources=.directory~new
::method register
  expose sources
  use strict arg sourceId,source
  id=sourceId~string~strip
  if id="" | source==.nil then raise syntax 88.900 array("instrumentation source id and source are required")
  sources[id]=source
  return source
::method source
  expose sources
  use strict arg sourceId
  return sources[sourceId~string]
::method sourceIds
  expose sources
  a=.array~new; do k over sources; a~append(k); end
  return a
::method snapshots
  expose sources
  use strict arg observedAt=""
  a=.array~new
  do k over sources
    a~append(sources[k]~snapshot(observedAt))
  end
  return a

/* ====================================================================== */
/* Local bounded history for queries and rate derivation. It is operational
 * evidence, not a billing ledger or durable audit authority. */
::class InstrumentationHistory public
::method init
  expose maxItems items
  use strict arg maxItemsArg=1024
  maxItems=maxItemsArg; if maxItems<1 then maxItems=1
  items=.array~new
::method append
  expose maxItems items
  use strict arg snapshot
  items~append(snapshot)
  do while items~items>maxItems; items~remove(1); end
  return snapshot
::method all
  expose items
  out=.array~new; do x over items; out~append(x); end
  return out
::method latest
  expose items
  if items~items=0 then return .nil
  return items[items~items]

/* ====================================================================== */
::class InstrumentationService public
::method init
  expose registry history authorizer commandTarget capabilities
  use strict arg registryArg,historyArg=.nil,authorizerArg=.nil,commandTargetArg=.nil,capabilitiesArg=.nil
  registry=registryArg
  if historyArg==.nil then history=.InstrumentationHistory~new; else history=historyArg
  authorizer=authorizerArg; commandTarget=commandTargetArg; capabilities=capabilitiesArg

::method sampleAll
  expose registry history
  use strict arg observedAt=""
  snapshots=registry~snapshots(observedAt)
  do s over snapshots; history~append(s); end
  return snapshots

::method handleQuery
  expose history
  use strict arg request
  if request==.nil | \request~isA(.Directory) then return .InstrumentationCodec~reply(.directory~new,"ERROR",.nil,"REQUEST_INVALID")
  if .InstrumentationCodec~value(request,"schema","")<>.InstrumentationContract~QUERY_SCHEMA then return .InstrumentationCodec~reply(request,"ERROR",.nil,"SCHEMA_INVALID")
  if .InstrumentationCodec~value(request,"api","")<>.InstrumentationContract~API then return .InstrumentationCodec~reply(request,"ERROR",.nil,"CONTRACT_MISMATCH")
  return .InstrumentationCodec~reply(request,"OK",history~all,"QUERY_RESULT")

::method handleCommand
  expose authorizer commandTarget
  use strict arg authenticatedPeer,command
  if command==.nil | \command~isA(.Directory) then return .InstrumentationCodec~commandResult(.directory~new,"ERROR","COMMAND_INVALID")
  if .InstrumentationCodec~value(command,"schema","")<>.InstrumentationContract~COMMAND_SCHEMA then return .InstrumentationCodec~commandResult(command,"ERROR","SCHEMA_INVALID")
  if .InstrumentationCodec~value(command,"api","")<>.InstrumentationContract~API then return .InstrumentationCodec~commandResult(command,"ERROR","CONTRACT_MISMATCH")
  if authenticatedPeer~string~strip="" then return .InstrumentationCodec~commandResult(command,"DENIED","AUTHENTICATED_PEER_REQUIRED")
  if authorizer==.nil then return .InstrumentationCodec~commandResult(command,"DENIED","NO_MANAGEMENT_AUTHORITY")
  if \authorizer~allowed(authenticatedPeer,command) then return .InstrumentationCodec~commandResult(command,"DENIED","NOT_AUTHORISED")
  if commandTarget==.nil then return .InstrumentationCodec~commandResult(command,"ERROR","NO_COMMAND_TARGET")
  commandReply=commandTarget~instrumentationCommand(.InstrumentationCodec~value(command,"operation",""),command["args"],authenticatedPeer,command)
  return .InstrumentationCodec~commandResult(command,"OK","COMMAND_COMPLETED","",commandReply)

/* Remote entry point.  Queue/XTP authenticates the peer; the payload is never
 * allowed to assert its own transport identity.  Queries require an
 * authenticated peer even when no additional query authorizer is installed. */
::method handleFrom
  expose authorizer
  use strict arg authenticatedPeer,payload
  peer=authenticatedPeer~string~strip
  if payload==.nil | \payload~isA(.Directory) then return .InstrumentationCodec~reply(.directory~new,"ERROR",.nil,"REQUEST_INVALID")
  schema=.InstrumentationCodec~value(payload,"schema","")
  if schema=.InstrumentationContract~QUERY_SCHEMA then do
    if peer="" then return .InstrumentationCodec~reply(payload,"DENIED",.nil,"AUTHENTICATED_PEER_REQUIRED")
    if authorizer<>.nil then do
      if authorizer~hasMethod("ALLOWEDQUERY") then do
        if \authorizer~allowedQuery(peer,payload) then return .InstrumentationCodec~reply(payload,"DENIED",.nil,"NOT_AUTHORISED")
      end
    end
    return self~handleQuery(payload)
  end
  if schema=.InstrumentationContract~COMMAND_SCHEMA then return self~handleCommand(peer,payload)
  return .InstrumentationCodec~reply(payload,"ERROR",.nil,"SCHEMA_INVALID")

/* ====================================================================== */
/* Selector semantics are identity-based.  Location/metric dimensions remain
 * evidence and do not become a second service identity namespace. */
::class InstrumentationSelection public
::method matches class
  use strict arg snapshot,selector=.nil
  if selector==.nil then return .true
  if selector~items=0 then return .true
  identity=snapshot["identity"]
  do key over selector
    expected=selector[key]
    select
      when key="semantic_ref" then actual=.InstrumentationCodec~value(snapshot,"semantic_ref",.InstrumentationCodec~semanticRef(identity))
      when key="estate_id" then actual=.InstrumentationCodec~value(identity,"estate_id","")
      when key="service_id" then actual=.InstrumentationCodec~value(identity,"service_id","")
      when key="instance_id" then actual=.InstrumentationCodec~value(identity,"instance_id","")
      when key="node_id" then actual=.InstrumentationCodec~value(identity,"node_id","")
      when key="mi_id" then actual=.InstrumentationCodec~value(identity,"mi_id","")
      when key="service_kind" then actual=.InstrumentationCodec~value(identity,"service_kind","")
      otherwise iterate
    end
    if actual~string<>expected~string then return .false
  end
  return .true

::method sampleMatches class
  use strict arg sample,metricName,dimensions=.nil
  if sample==.nil then return .false
  if .InstrumentationCodec~value(sample,"name","")<>metricName then return .false
  actualDims=sample["dimensions"]
  if actualDims==.nil then actualDims=.directory~new
  if dimensions==.nil then return actualDims~items=0
  do key over dimensions
    if .InstrumentationCodec~value(actualDims,key,"")~string<>dimensions[key]~string then return .false
  end
  return .true

/* Collector accepts complete publication batches atomically.  Per-publisher
 * sequence fencing makes replay idempotent and rejects stale/conflicting data.
 * Stored and returned object graphs are detached copies. */
::class InstrumentationCollector public
::method init
  expose maxPerIdentity histories latestByKey publisherSequences publisherIds consumers consumerFailures
  use strict arg maxPerIdentityArg=256
  maxPerIdentity=maxPerIdentityArg
  if \datatype(maxPerIdentity,"W") | maxPerIdentity<1 then maxPerIdentity=256
  histories=.directory~new; latestByKey=.directory~new
  publisherSequences=.directory~new; publisherIds=.directory~new
  consumers=.array~new; consumerFailures=0

::attribute consumerFailures get

::method subscribe
  expose consumers
  use strict arg consumer
  if consumer==.nil then return .false
  do existing over consumers
    if existing==consumer then return .true
  end
  consumers~append(consumer)
  return .true

::method acceptFrom
  use strict arg authenticatedPeer,publication
  if authenticatedPeer~string~strip="" then return .InstrumentationCodec~publicationReceipt(publication,"DENIED","AUTHENTICATED_PEER_REQUIRED")
  return self~accept(publication)

::method accept
  expose maxPerIdentity histories latestByKey publisherSequences publisherIds consumers consumerFailures
  use strict arg publication
  if publication==.nil | \publication~isA(.Directory) then return .InstrumentationCodec~publicationReceipt(.directory~new,"ERROR","PUBLICATION_INVALID")
  if .InstrumentationCodec~value(publication,"schema","")<>.InstrumentationContract~PUBLICATION_SCHEMA then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","SCHEMA_INVALID")
  if .InstrumentationCodec~value(publication,"api","")<>.InstrumentationContract~API then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","CONTRACT_MISMATCH")
  publicationId=.InstrumentationCodec~value(publication,"publication_id","")~string~strip
  publisherId=.InstrumentationCodec~value(publication,"publisher_id","")~string~strip
  sequence=.InstrumentationCodec~value(publication,"sequence",0)
  if publicationId="" | publisherId="" | \datatype(sequence,"W") | sequence<1 then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","PUBLICATION_FIELDS_INVALID")
  lastSequence=publisherSequences[publisherId]
  if lastSequence<>.nil then do
    if sequence<lastSequence then return .InstrumentationCodec~publicationReceipt(publication,"DENIED","STALE_PUBLICATION")
    if sequence=lastSequence then do
      if publisherIds[publisherId]=publicationId then return .InstrumentationCodec~publicationReceipt(publication,"OK","REPLAY",0)
      return .InstrumentationCodec~publicationReceipt(publication,"DENIED","SEQUENCE_CONFLICT")
    end
  end
  snapshots=publication["snapshots"]
  if snapshots==.nil | \snapshots~isA(.Array) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","SNAPSHOTS_INVALID")
  /* Validate the entire batch before mutating collector state. */
  do snapshot over snapshots
    if \self~validSnapshot(snapshot) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","SNAPSHOT_INVALID")
  end
  accepted=.array~new
  do snapshot over snapshots
    stored=.InstrumentationCodec~copyValue(snapshot)
    key=.InstrumentationCodec~identityKey(stored["identity"])
    h=histories[key]
    if h==.nil then do; h=.array~new; histories[key]=h; end
    h~append(stored)
    do while h~items>maxPerIdentity; h~remove(1); end
    latestByKey[key]=stored
    accepted~append(.InstrumentationCodec~copyValue(stored))
  end
  publisherSequences[publisherId]=sequence; publisherIds[publisherId]=publicationId
  do consumer over consumers
    if consumer~hasMethod("INSTRUMENTATIONUPDATED") then do
      if \self~notifyOne(consumer,publication,accepted) then consumerFailures+=1
    end
  end
  return .InstrumentationCodec~publicationReceipt(publication,"OK","ACCEPTED","",accepted~items)

::method notifyOne
  use strict arg consumer,publication,accepted
  signal on syntax name consumerFailed
  ignore=consumer~instrumentationUpdated(.InstrumentationCodec~copyValue(publication),.InstrumentationCodec~copyValue(accepted))
  signal off syntax
  return .true
consumerFailed:
  say "INSTRUMENTATION_CONSUMER_FAILURE rc="rc "sigl="sigl "condition="condition("C") "detail="condition("D")
  signal off syntax
  return .false

::method validSnapshot
  use strict arg snapshot
  if snapshot==.nil | \snapshot~isA(.Directory) then return .false
  if .InstrumentationCodec~value(snapshot,"schema","")<>.InstrumentationContract~SNAPSHOT_SCHEMA then return .false
  if .InstrumentationCodec~value(snapshot,"api","")<>.InstrumentationContract~API then return .false
  identity=snapshot["identity"]
  if identity==.nil | \identity~isA(.Directory) then return .false
  if .InstrumentationCodec~value(identity,"estate_id","")="" then return .false
  if .InstrumentationCodec~value(identity,"service_id","")="" then return .false
  if .InstrumentationCodec~value(identity,"instance_id","")="" then return .false
  if .InstrumentationCodec~value(identity,"node_id","")="" then return .false
  samples=snapshot["samples"]
  if samples==.nil | \samples~isA(.Array) then return .false
  return .true

::method latest
  expose latestByKey
  use strict arg selector=.nil
  out=.array~new
  do key over latestByKey
    snapshot=latestByKey[key]
    if .InstrumentationSelection~matches(snapshot,selector) then out~append(.InstrumentationCodec~copyValue(snapshot))
  end
  return out

::method latestBySemanticRef
  expose latestByKey
  use strict arg semanticRef
  do key over latestByKey
    snapshot=latestByKey[key]
    if .InstrumentationCodec~value(snapshot,"semantic_ref",.InstrumentationCodec~semanticRef(snapshot["identity"]))=semanticRef then return .InstrumentationCodec~copyValue(snapshot)
  end
  return .nil

::method history
  expose histories
  use strict arg selector=.nil,limit=0
  out=.array~new
  do key over histories
    h=histories[key]
    start=1
    if datatype(limit,"W") then do
      if limit>0 then if h~items>limit then start=h~items-limit+1
    end
    do i=start to h~items
      snapshot=h[i]
      if .InstrumentationSelection~matches(snapshot,selector) then out~append(.InstrumentationCodec~copyValue(snapshot))
    end
  end
  return out

::method historyBySemanticRef
  use strict arg semanticRef,limit=0
  selector=.directory~new; selector["semantic_ref"]=semanticRef
  return self~history(selector,limit)

::method series
  use strict arg semanticRef,metricName,dimensions=.nil,limit=0
  history=self~historyBySemanticRef(semanticRef,limit)
  out=.array~new
  do snapshot over history
    do sample over snapshot["samples"]
      if \.InstrumentationSelection~sampleMatches(sample,metricName,dimensions) then iterate
      point=.directory~new
      point["semantic_ref"]=semanticRef
      point["metric"]=metricName
      point["observed_at"]=.InstrumentationCodec~value(sample,"observed_at",.InstrumentationCodec~value(snapshot,"observed_at",""))
      point["value"]=sample["value"]
      point["unit"]=.InstrumentationCodec~value(sample,"unit","")
      point["kind"]=.InstrumentationCodec~value(sample,"kind","")
      point["dimensions"]=.InstrumentationCodec~copyValue(sample["dimensions"])
      out~append(point)
    end
  end
  return out

::method query
  use strict arg request
  mode=.InstrumentationCodec~value(request,"mode","HISTORY")~string~upper
  selector=request["selector"]
  limit=.InstrumentationCodec~value(request,"limit",0)
  select
    when mode="LATEST" then payload=self~latest(selector)
    when mode="HISTORY" | mode="SNAPSHOTS" then payload=self~history(selector,limit)
    when mode="SERIES" then do
      semanticRef=.InstrumentationCodec~value(selector,"semantic_ref","")
      metricNames=request["metrics"]
      if semanticRef="" | metricNames==.nil | metricNames~items=0 then return .InstrumentationCodec~reply(request,"ERROR",.nil,"SERIES_SELECTOR_REQUIRED")
      payload=.array~new
      do metricName over metricNames
        one=.directory~new
        one["semantic_ref"]=semanticRef
        one["metric"]=metricName
        one["points"]=self~series(semanticRef,metricName,.nil,limit)
        payload~append(one)
      end
    end
    otherwise return .InstrumentationCodec~reply(request,"ERROR",.nil,"QUERY_MODE_UNSUPPORTED")
  end
  return .InstrumentationCodec~reply(request,"OK",payload,"QUERY_RESULT")

/* Network read-side service.  Publication and query both require an already
 * authenticated mesh peer.  It has no mutation command surface. */
::class InstrumentationCollectorService public
::method init
  expose collector queryAuthorizer
  use strict arg collectorArg,queryAuthorizerArg=.nil
  collector=collectorArg; queryAuthorizer=queryAuthorizerArg

::method handleFrom
  expose collector queryAuthorizer
  use strict arg authenticatedPeer,payload
  peer=authenticatedPeer~string~strip
  if payload==.nil | \payload~isA(.Directory) then return .InstrumentationCodec~reply(.directory~new,"ERROR",.nil,"REQUEST_INVALID")
  schema=.InstrumentationCodec~value(payload,"schema","")
  if schema=.InstrumentationContract~PUBLICATION_SCHEMA then return collector~acceptFrom(peer,payload)
  if schema=.InstrumentationContract~QUERY_SCHEMA then do
    if peer="" then return .InstrumentationCodec~reply(payload,"DENIED",.nil,"AUTHENTICATED_PEER_REQUIRED")
    if queryAuthorizer<>.nil then if queryAuthorizer~hasMethod("ALLOWEDQUERY") then if \queryAuthorizer~allowedQuery(peer,payload) then return .InstrumentationCodec~reply(payload,"DENIED",.nil,"NOT_AUTHORISED")
    return collector~query(payload)
  end
  return .InstrumentationCodec~reply(payload,"ERROR",.nil,"SCHEMA_INVALID")

/* Publisher is deliberately clock/scheduler neutral.  A deployment timer,
 * Queue job, RexxOS service loop or test invokes publish() at its own cadence. */
::class InstrumentationPublisher public
::method init
  expose publisherId service transport collectorPeer sequence
  use strict arg publisherIdArg,serviceArg,transportArg,collectorPeerArg
  publisherId=publisherIdArg~string~strip
  if publisherId="" then raise syntax 88.900 array("instrumentation publisher id is required")
  service=serviceArg; transport=transportArg; collectorPeer=collectorPeerArg~string~strip; sequence=0
  if collectorPeer="" then raise syntax 88.900 array("instrumentation collector peer is required")

::method publish
  expose publisherId service transport collectorPeer sequence
  use strict arg observedAt=""
  snapshots=service~sampleAll(observedAt)
  sequence+=1
  publicationId=publisherId||"-"||sequence
  publication=.InstrumentationCodec~publication(publicationId,publisherId,sequence,snapshots,observedAt)
  receipt=transport~request(collectorPeer,publication)
  if receipt==.nil | \receipt~isA(.Directory) then return .InstrumentationPublisherResult~failure("NO_RECEIPT")
  if .InstrumentationCodec~value(receipt,"schema","")<>.InstrumentationContract~PUBLICATION_RECEIPT_SCHEMA then return .InstrumentationPublisherResult~failure("RECEIPT_SCHEMA_INVALID")
  status=.InstrumentationCodec~value(receipt,"status","")
  if status<>"OK" then return .InstrumentationPublisherResult~failure(.InstrumentationCodec~value(receipt,"code","PUBLICATION_REJECTED"),receipt)
  return .InstrumentationPublisherResult~success(publication,receipt)

::class InstrumentationPublisherResult public
::attribute ok get
::attribute code get
::attribute publication get
::attribute receipt get
::method init
  expose ok code publication receipt
  use strict arg okArg,codeArg,publicationArg=.nil,receiptArg=.nil
  ok=(okArg==.true); code=codeArg~string; publication=publicationArg; receipt=receiptArg
::method success class
  use strict arg publicationArg,receiptArg
  return self~new(.true,"OK",publicationArg,receiptArg)
::method failure class
  use strict arg codeArg,receiptArg=.nil
  return self~new(.false,codeArg,.nil,receiptArg)

/* Local transport is useful for process-local composition and qualification;
 * production mesh publishing uses the same request(peer,payload) seam through
 * InstrumentationQueueRexxClientTransport. */
::class InstrumentationLocalCollectorTransport public
::method init
  expose collectorService authenticatedPeer
  use strict arg collectorServiceArg,authenticatedPeerArg="local"
  collectorService=collectorServiceArg; authenticatedPeer=authenticatedPeerArg~string
::method request
  expose collectorService authenticatedPeer
  use strict arg peerNodeId,payload
  return collectorService~handleFrom(authenticatedPeer,payload)

/* ====================================================================== */
/* Queue carrier seam. A Queue Fabric adapter implements request(peer,payload)
 * and bind(route,handler,securityDomain). This class never opens sockets. */
::class InstrumentationQueueBinding public
::method init
  expose transport service
  use strict arg transportArg,serviceArg
  transport=transportArg; service=serviceArg
::method bind
  expose transport service
  return transport~bind(.InstrumentationContract~QUEUE_SERVICE_ROUTE,service,.InstrumentationContract~SECURITY_DOMAIN)
::method request
  expose transport
  use strict arg peerNodeId,payload
  return transport~request(peerNodeId,payload)
