/* InstrumentationMesh.cls
 * Estate-wide operational instrumentation language and mesh service.
 * API: instrumentation.mesh/0.1
 *
 * Instrumentation owns observations, vocabulary, query semantics and the
 * management request envelope. Queue Fabric is the preferred carrier, but is
 * deliberately not an authority dependency of this class file.
 */

::class InstrumentationBuild public
::constant VERSION "0.1-dev8"
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
::constant RELATIONSHIP_SCHEMA "instrumentation.relationship/1"
::constant RELATIONSHIP_SET_SCHEMA "instrumentation.relationship-set/1"
::constant EVENT_SCHEMA "instrumentation.event/1"
::constant CORRELATION_SCHEMA "instrumentation.correlation/1"
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
::constant OPERATION_STARTED_TOTAL "operation.started.total"
::constant OPERATION_COMPLETED_TOTAL "operation.completed.total"
::constant OPERATION_FAILED_TOTAL "operation.failed.total"
::constant OPERATION_CANCELLED_TOTAL "operation.cancelled.total"
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

::class InstrumentationEventSeverity public
::constant INFO "INFO"
::constant NOTICE "NOTICE"
::constant WARNING "WARNING"
::constant ERROR "ERROR"
::constant CRITICAL "CRITICAL"

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

::method dimensionKey class
  use strict arg dimensions=.nil
  if dimensions==.nil then return ""
  if dimensions~items=0 then return ""
  keys=dimensions~allIndexes
  if keys~items>1 then keys~sort
  out=""
  do key over keys
    k=key~string
    value=dimensions[key]
    if value==.nil then v=""
    else v=value~string
    out=out||length(k)||":"||k||length(v)||":"||v
  end
  return out

::method metricSeriesKey class
  use strict arg name,dimensions=.nil
  return name~string||"1E"x||self~dimensionKey(dimensions)

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

/* Events are bounded operational observations.  A source event reports that
 * the named authority observed an occurrence.  A derived event explicitly
 * reports a collector-side change in observed evidence; it is never promoted
 * into the source authority's state transition. */
::method event class
  use strict arg eventId,kind,subjectRef,authority,observedAt="",severity="INFO",correlationId="",operationId="",detail="",relatedRefs=.nil,evidence=.nil,dimensions=.nil,derived=.false,causationId="",contextRefs=.nil
  id=eventId~string~strip
  eventKind=kind~string~strip~upper
  subject=subjectRef~string~strip
  sourceAuthority=authority~string~strip
  level=severity~string~strip~upper
  if id="" | eventKind="" | subject="" | sourceAuthority="" then raise syntax 88.900 array("instrumentation event identity, kind, subject and authority are required")
  if relatedRefs==.nil then relatedRefs=.array~new
  if \relatedRefs~isA(.Array) then raise syntax 88.900 array("instrumentation event related refs must be an Array")
  if contextRefs==.nil then contextRefs=.array~new
  if \contextRefs~isA(.Array) then raise syntax 88.900 array("instrumentation event context refs must be an Array")
  d=.directory~new
  d["schema"]=.InstrumentationContract~EVENT_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["event_id"]=id
  d["kind"]=eventKind
  d["subject_ref"]=subject
  d["authority"]=sourceAuthority
  d["observed_at"]=observedAt~string
  d["severity"]=level
  d["correlation_id"]=correlationId~string
  d["causation_id"]=causationId~string
  d["operation_id"]=operationId~string
  d["detail"]=detail~string
  d["related_refs"]=self~copyValue(relatedRefs)
  d["context_refs"]=self~copyValue(contextRefs)
  d["dimensions"]=self~copyDirectory(dimensions)
  if evidence<>.nil then d["evidence"]=self~copyValue(evidence)
  d["derived"]=(derived==.true)
  return d

::method eventKey class
  use strict arg event
  return self~value(event,"authority","")||"1F"x||self~value(event,"event_id","")

/* Relationship observations describe current domain-owned edges.  The
 * publisher states the authority and completeness of a scope; Instrumentation
 * retains that evidence but never invents or owns topology. */
::method relationship class
  use strict arg relationshipId,kind,fromRef,toRef,authority,observedAt="",state="PRESENT",evidence=.nil,dimensions=.nil
  id=relationshipId~string~strip
  relationKind=kind~string~strip~upper
  sourceRef=fromRef~string~strip
  targetRef=toRef~string~strip
  sourceAuthority=authority~string~strip
  relationState=state~string~strip~upper
  if id="" | relationKind="" | sourceRef="" | targetRef="" | sourceAuthority="" then raise syntax 88.900 array("instrumentation relationship identity, kind, endpoints and authority are required")
  if relationState<>"PRESENT" then if relationState<>"WITHDRAWN" then raise syntax 88.900 array("instrumentation relationship state must be PRESENT or WITHDRAWN")
  d=.directory~new
  d["schema"]=.InstrumentationContract~RELATIONSHIP_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["relationship_id"]=id
  d["kind"]=relationKind
  d["from_ref"]=sourceRef
  d["to_ref"]=targetRef
  d["authority"]=sourceAuthority
  d["state"]=relationState
  d["observed_at"]=observedAt~string
  d["dimensions"]=self~copyDirectory(dimensions)
  if evidence<>.nil then d["evidence"]=self~copyValue(evidence)
  return d

::method relationshipSet class
  use strict arg scopeId,authority,complete,relationships,observedAt="",generation=""
  scope=scopeId~string~strip
  sourceAuthority=authority~string~strip
  if scope="" | sourceAuthority="" then raise syntax 88.900 array("instrumentation relationship scope and authority are required")
  if relationships==.nil | \relationships~isA(.Array) then raise syntax 88.900 array("instrumentation relationship set requires an Array")
  d=.directory~new
  d["schema"]=.InstrumentationContract~RELATIONSHIP_SET_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["scope_id"]=scope
  d["authority"]=sourceAuthority
  d["complete"]=(complete==.true)
  d["observed_at"]=observedAt~string
  d["generation"]=generation~string
  d["relationships"]=self~copyValue(relationships)
  return d

::method relationshipSetKey class
  use strict arg relationshipSet
  return self~value(relationshipSet,"authority","")||"1F"x||self~value(relationshipSet,"scope_id","")

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
  use strict arg publicationId,publisherId,sequence,snapshots,observedAt="",publishedPosixSeconds=.nil,relationshipSets=.nil,events=.nil
  d=.directory~new
  d["schema"]=.InstrumentationContract~PUBLICATION_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["publication_id"]=publicationId~string
  d["publisher_id"]=publisherId~string
  d["sequence"]=sequence
  d["observed_at"]=observedAt~string
  if publishedPosixSeconds<>.nil then d["published_posix_seconds"]=publishedPosixSeconds
  d["snapshots"]=self~copyValue(snapshots)
  if relationshipSets==.nil then relationshipSets=.array~new
  d["relationship_sets"]=self~copyValue(relationshipSets)
  if events==.nil then events=.array~new
  d["events"]=self~copyValue(events)
  return d

::method publicationReceipt class
  use strict arg publication,status,code="",detail="",accepted=0,acceptedRelationshipSets=0,acceptedEvents=0
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
  d["accepted_relationship_sets"]=acceptedRelationshipSets
  d["accepted_events"]=acceptedEvents
  return d

/* ====================================================================== */
/* Mutable counters are kept inside a service-local emitter. Snapshot output
 * is a newly built object graph so callers cannot mutate authoritative state. */
::class InstrumentationEmitter public
::method init
  expose identity health counters gauges units kinds dimensions metricNames progresses sequence
  use strict arg identityArg
  identity=identityArg
  health=.InstrumentationHealth~STARTING
  counters=.directory~new; gauges=.directory~new; units=.directory~new
  kinds=.directory~new; dimensions=.directory~new; metricNames=.directory~new; progresses=.directory~new
  sequence=0

::method setHealth
  expose health
  use strict arg healthArg
  health=healthArg~string~upper
  return self

::method counterAdd
  expose counters units kinds dimensions metricNames
  use strict arg name,delta=1,unit="count",dims=.nil
  copiedDims=.InstrumentationCodec~copyDirectory(dims)
  seriesKey=.InstrumentationCodec~metricSeriesKey(name,copiedDims)
  old=counters[seriesKey]
  if old==.nil then old=0
  counters[seriesKey]=old+delta
  units[seriesKey]=unit~string; kinds[seriesKey]=.InstrumentationMetricKind~COUNTER
  dimensions[seriesKey]=copiedDims; metricNames[seriesKey]=name~string
  return counters[seriesKey]

::method counterValue
  expose counters
  use strict arg name,dims=.nil
  seriesKey=.InstrumentationCodec~metricSeriesKey(name,dims)
  value=counters[seriesKey]
  if value==.nil then return 0
  return value

::method gaugeSet
  expose gauges units kinds dimensions metricNames
  use strict arg name,value,unit="count",dims=.nil,kind=""
  if kind="" then kind=.InstrumentationMetricKind~GAUGE
  gauges[name]=value
  units[name]=unit~string; kinds[name]=kind~string~upper
  dimensions[name]=.InstrumentationCodec~copyDirectory(dims); metricNames[name]=name~string
  return value

/* Explicit dimensional gauge series.  gaugeSet() retains the established
 * latest-value-by-name behavior used by current producers such as NoSQLServer.
 * Services that own several simultaneously meaningful dimensional gauge values
 * use this method so they cannot overwrite one another. */
::method gaugeSeriesSet
  expose gauges units kinds dimensions metricNames
  use strict arg name,value,unit="count",dims=.nil,kind=""
  if kind="" then kind=.InstrumentationMetricKind~GAUGE
  copiedDims=.InstrumentationCodec~copyDirectory(dims)
  seriesKey=.InstrumentationCodec~metricSeriesKey(name,copiedDims)
  gauges[seriesKey]=value
  units[seriesKey]=unit~string; kinds[seriesKey]=kind~string~upper
  dimensions[seriesKey]=copiedDims; metricNames[seriesKey]=name~string
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
  use strict arg name,dims=.nil
  if dims==.nil then seriesKey=name~string
  else seriesKey=.InstrumentationCodec~metricSeriesKey(name,dims)
  v=gauges[seriesKey]; if v==.nil then return 0
  return v
::method snapshot
  expose identity health counters gauges units kinds dimensions metricNames progresses sequence
  use strict arg observedAt=""
  sequence+=1
  samples=.array~new
  do seriesKey over counters
    samples~append(.InstrumentationCodec~sample(metricNames[seriesKey],kinds[seriesKey],units[seriesKey],counters[seriesKey],observedAt,dimensions[seriesKey]))
  end
  do seriesKey over gauges
    samples~append(.InstrumentationCodec~sample(metricNames[seriesKey],kinds[seriesKey],units[seriesKey],gauges[seriesKey],observedAt,dimensions[seriesKey]))
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
    source=sources[k]
    if source~hasMethod("SNAPSHOTS") then do
      batch=source~snapshots(observedAt)
      if batch==.nil | \batch~isA(.Array) then raise syntax 88.900 array("instrumentation multi-snapshot source must return an Array: "||k)
      do snapshot over batch
        if snapshot==.nil then raise syntax 88.900 array("instrumentation source returned NIL snapshot: "||k)
        a~append(snapshot)
      end
    end
    else if source~hasMethod("SNAPSHOT") then do
      snapshot=source~snapshot(observedAt)
      if snapshot==.nil then raise syntax 88.900 array("instrumentation source returned NIL snapshot: "||k)
      a~append(snapshot)
    end
    else if source~hasMethod("INSTRUMENTATIONSNAPSHOT") then do
      snapshot=source~instrumentationSnapshot(observedAt)
      if snapshot==.nil then raise syntax 88.900 array("instrumentation service has no registered snapshot: "||k)
      a~append(snapshot)
    end
    else if source~hasMethod("RELATIONSHIPSET") | source~hasMethod("RELATIONSHIPSETS") | source~hasMethod("EVENTS") then nop
    else raise syntax 88.900 array("instrumentation source exposes no snapshot, relationship or event source method: "||k)
  end
  return a

/* Relationship sources are optional.  A relationship set is a complete or
 * explicitly partial observation of one authority-owned scope. */
::method relationshipSets
  expose sources
  use strict arg observedAt=""
  out=.array~new
  do k over sources
    source=sources[k]
    if source~hasMethod("RELATIONSHIPSETS") then do
      batch=source~relationshipSets(observedAt)
      if batch==.nil | \batch~isA(.Array) then raise syntax 88.900 array("instrumentation relationship source must return an Array: "||k)
      do relationshipSet over batch
        if relationshipSet==.nil then raise syntax 88.900 array("instrumentation source returned NIL relationship set: "||k)
        out~append(relationshipSet)
      end
    end
    else if source~hasMethod("RELATIONSHIPSET") then do
      relationshipSet=source~relationshipSet(observedAt)
      if relationshipSet==.nil then raise syntax 88.900 array("instrumentation source returned NIL relationship set: "||k)
      out~append(relationshipSet)
    end
  end
  return out

/* Event sources expose a retained bounded event journal.  Publishers may send
 * the same event again in later publications; collector event-id fencing makes
 * that replay idempotent, avoiding event loss when an earlier publication
 * receipt was unavailable. */
::method events
  expose sources
  use strict arg observedAt=""
  out=.array~new
  do k over sources
    source=sources[k]
    if source~hasMethod("EVENTS") then do
      batch=source~events(observedAt)
      if batch==.nil | \batch~isA(.Array) then raise syntax 88.900 array("instrumentation event source must return an Array: "||k)
      do event over batch
        if event==.nil then raise syntax 88.900 array("instrumentation source returned NIL event: "||k)
        out~append(event)
      end
    end
  end
  return out

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
  if items~items>maxItems then do
    trimmed=.array~new
    start=items~items-maxItems+1
    do i=start to items~items
      trimmed~append(items[i])
    end
    items=trimmed
  end
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

::method sampleRelationships
  expose registry
  use strict arg observedAt=""
  return registry~relationshipSets(observedAt)

::method sampleEvents
  expose registry
  use strict arg observedAt=""
  return registry~events(observedAt)

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
  if dimensions==.nil then return .true
  if dimensions~items=0 then return actualDims~items=0
  do key over dimensions
    if .InstrumentationCodec~value(actualDims,key,"")~string<>dimensions[key]~string then return .false
  end
  return .true

::method eventMatches class
  use strict arg event,selector=.nil
  if selector==.nil then return .true
  if selector~items=0 then return .true
  do key over selector
    expected=selector[key]
    select
      when key="event_id" then actual=.InstrumentationCodec~value(event,"event_id","")
      when key="kind" then actual=.InstrumentationCodec~value(event,"kind","")
      when key="subject_ref" then actual=.InstrumentationCodec~value(event,"subject_ref","")
      when key="authority" then actual=.InstrumentationCodec~value(event,"authority","")
      when key="severity" then actual=.InstrumentationCodec~value(event,"severity","")
      when key="correlation_id" then actual=.InstrumentationCodec~value(event,"correlation_id","")
      when key="causation_id" then actual=.InstrumentationCodec~value(event,"causation_id","")
      when key="operation_id" then actual=.InstrumentationCodec~value(event,"operation_id","")
      when key="derived" then actual=.InstrumentationCodec~value(event,"derived",.false)
      when key="context_ref" then do
        if \self~arrayContains(event["context_refs"],expected) then return .false
        iterate
      end
      when key="related_ref" then do
        if \self~arrayContains(event["related_refs"],expected) then return .false
        iterate
      end
      otherwise iterate
    end
    if actual~string<>expected~string then return .false
  end
  return .true

::method arrayContains class
  use strict arg values,expected
  if values==.nil | \values~isA(.Array) then return .false
  do value over values
    if value~string=expected~string then return .true
  end
  return .false

::method relationshipMatches class
  use strict arg relationship,selector=.nil
  if selector==.nil then return .true
  if selector~items=0 then return .true
  do key over selector
    expected=selector[key]
    select
      when key="relationship_id" then actual=.InstrumentationCodec~value(relationship,"relationship_id","")
      when key="kind" then actual=.InstrumentationCodec~value(relationship,"kind","")
      when key="from_ref" then actual=.InstrumentationCodec~value(relationship,"from_ref","")
      when key="to_ref" then actual=.InstrumentationCodec~value(relationship,"to_ref","")
      when key="authority" then actual=.InstrumentationCodec~value(relationship,"authority","")
      when key="state" then actual=.InstrumentationCodec~value(relationship,"state","")
      otherwise iterate
    end
    if actual~string<>expected~string then return .false
  end
  return .true

::method relationshipSetMatches class
  use strict arg relationshipSet,selector=.nil
  if selector==.nil then return .true
  if selector~items=0 then return .true
  do key over selector
    expected=selector[key]
    select
      when key="scope_id" then actual=.InstrumentationCodec~value(relationshipSet,"scope_id","")
      when key="set_authority" then actual=.InstrumentationCodec~value(relationshipSet,"authority","")
      when key="complete" then actual=.InstrumentationCodec~value(relationshipSet,"complete",.false)
      otherwise iterate
    end
    if actual~string<>expected~string then return .false
  end
  return .true

/* Collector accepts complete publication batches atomically.  Per-publisher
 * sequence fencing makes replay idempotent and rejects stale/conflicting data.
 * Stored and returned object graphs are detached copies. */
::class InstrumentationCollector public
::method init
  expose maxPerIdentity histories latestByKey publisherSequences publisherIds consumers consumerFailures publicationEvidenceByKey relationshipHistories latestRelationshipSets eventHistory eventSeen eventSeenOrder eventSeenLimit
  use strict arg maxPerIdentityArg=256
  maxPerIdentity=maxPerIdentityArg
  if \datatype(maxPerIdentity,"W") | maxPerIdentity<1 then maxPerIdentity=256
  histories=.directory~new; latestByKey=.directory~new
  publisherSequences=.directory~new; publisherIds=.directory~new
  publicationEvidenceByKey=.directory~new
  relationshipHistories=.directory~new; latestRelationshipSets=.directory~new
  eventHistory=.array~new; eventSeen=.directory~new; eventSeenOrder=.array~new; eventSeenLimit=maxPerIdentity*8
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
  expose maxPerIdentity histories latestByKey publisherSequences publisherIds consumers consumerFailures publicationEvidenceByKey relationshipHistories latestRelationshipSets eventHistory eventSeen eventSeenOrder eventSeenLimit
  use strict arg publication
  numeric digits 20
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
  publishedTicks=publication["published_posix_seconds"]
  if publishedTicks<>.nil then do
    if \datatype(publishedTicks,"W") then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","PUBLISHED_TIME_INVALID")
  end
  snapshots=publication["snapshots"]
  if snapshots==.nil | \snapshots~isA(.Array) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","SNAPSHOTS_INVALID")
  relationshipSets=publication["relationship_sets"]
  if relationshipSets==.nil then relationshipSets=.array~new
  if \relationshipSets~isA(.Array) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","RELATIONSHIP_SETS_INVALID")
  events=publication["events"]
  if events==.nil then events=.array~new
  if \events~isA(.Array) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","EVENTS_INVALID")
  /* Validate the entire batch before mutating collector state. */
  do snapshot over snapshots
    if \self~validSnapshot(snapshot) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","SNAPSHOT_INVALID")
  end
  do relationshipSet over relationshipSets
    if \self~validRelationshipSet(relationshipSet) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","RELATIONSHIP_SET_INVALID")
  end
  do event over events
    if \self~validEvent(event) then return .InstrumentationCodec~publicationReceipt(publication,"ERROR","EVENT_INVALID")
  end
  derivedEvents=.array~new
  accepted=.array~new
  do snapshot over snapshots
    stored=.InstrumentationCodec~copyValue(snapshot)
    key=.InstrumentationCodec~identityKey(stored["identity"])
    previous=latestByKey[key]
    self~appendAll(derivedEvents,self~deriveSnapshotEvents(previous,stored,publisherId,sequence))
    h=histories[key]
    if h==.nil then do; h=.array~new; histories[key]=h; end
    h~append(stored)
    if h~items>maxPerIdentity then do
      h=self~tailArray(h,maxPerIdentity)
      histories[key]=h
    end
    latestByKey[key]=stored
    evidence=.directory~new
    evidence["publisher_id"]=publisherId
    evidence["publication_id"]=publicationId
    evidence["sequence"]=sequence
    evidence["observed_at"]=.InstrumentationCodec~value(publication,"observed_at","")
    if publishedTicks<>.nil then evidence["published_posix_seconds"]=publishedTicks
    publicationEvidenceByKey[key]=evidence
    accepted~append(.InstrumentationCodec~copyValue(stored))
  end
  acceptedRelationshipSets=0
  do relationshipSet over relationshipSets
    storedSet=.InstrumentationCodec~copyValue(relationshipSet)
    relationshipKey=.InstrumentationCodec~relationshipSetKey(storedSet)
    previousSet=latestRelationshipSets[relationshipKey]
    self~appendAll(derivedEvents,self~deriveRelationshipEvents(previousSet,storedSet,publisherId,sequence))
    relationshipHistory=relationshipHistories[relationshipKey]
    if relationshipHistory==.nil then do
      relationshipHistory=.array~new
      relationshipHistories[relationshipKey]=relationshipHistory
    end
    relationshipHistory~append(storedSet)
    if relationshipHistory~items>maxPerIdentity then do
      relationshipHistory=self~tailArray(relationshipHistory,maxPerIdentity)
      relationshipHistories[relationshipKey]=relationshipHistory
    end
    latestRelationshipSets[relationshipKey]=storedSet
    acceptedRelationshipSets+=1
  end
  acceptedEvents=0
  do event over events
    if self~storeEvent(event) then acceptedEvents+=1
  end
  do event over derivedEvents
    if self~storeEvent(event) then acceptedEvents+=1
  end
  publisherSequences[publisherId]=sequence; publisherIds[publisherId]=publicationId
  do consumer over consumers
    if consumer~hasMethod("INSTRUMENTATIONUPDATED") then do
      if \self~notifyOne(consumer,publication,accepted) then consumerFailures+=1
    end
  end
  return .InstrumentationCodec~publicationReceipt(publication,"OK","ACCEPTED","",accepted~items,acceptedRelationshipSets,acceptedEvents)

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

::method appendAll
  use strict arg target,items
  do item over items; target~append(item); end
  return target

::method storeEvent
  expose maxPerIdentity eventHistory eventSeen eventSeenOrder eventSeenLimit
  use strict arg event
  key=.InstrumentationCodec~eventKey(event)
  if eventSeen[key]<>.nil then return .false
  stored=.InstrumentationCodec~copyValue(event)
  eventHistory~append(stored)
  eventSeen[key]=.true
  eventSeenOrder~append(key)
  if eventHistory~items>maxPerIdentity*4 then eventHistory=self~tailArray(eventHistory,maxPerIdentity*4)
  if eventSeenOrder~items>eventSeenLimit then do
    excess=eventSeenOrder~items-eventSeenLimit
    do i=1 to excess
      oldKey=eventSeenOrder[i]
      if eventSeen[oldKey]<>.nil then eventSeen~remove(oldKey)
    end
    eventSeenOrder=self~tailArray(eventSeenOrder,eventSeenLimit)
  end
  return .true

::method tailArray
  use strict arg source,limit
  out=.array~new
  if source==.nil then return out
  if \datatype(limit,"W") | limit<1 then return out
  start=1
  if source~items>limit then start=source~items-limit+1
  do i=start to source~items
    out~append(source[i])
  end
  return out

::method validEvent
  use strict arg event
  if event==.nil | \event~isA(.Directory) then return .false
  if .InstrumentationCodec~value(event,"schema","")<>.InstrumentationContract~EVENT_SCHEMA then return .false
  if .InstrumentationCodec~value(event,"api","")<>.InstrumentationContract~API then return .false
  if .InstrumentationCodec~value(event,"event_id","")="" then return .false
  if .InstrumentationCodec~value(event,"kind","")="" then return .false
  if .InstrumentationCodec~value(event,"subject_ref","")="" then return .false
  if .InstrumentationCodec~value(event,"authority","")="" then return .false
  related=event["related_refs"]
  if related==.nil | \related~isA(.Array) then return .false
  contexts=event["context_refs"]
  if contexts<>.nil then if \contexts~isA(.Array) then return .false
  return .true

::method eventsHistory
  expose eventHistory
  use strict arg selector=.nil,limit=0
  out=.array~new
  start=1
  if datatype(limit,"W") then do
    if limit>0 then if eventHistory~items>limit then start=eventHistory~items-limit+1
  end
  do i=start to eventHistory~items
    event=eventHistory[i]
    if .InstrumentationSelection~eventMatches(event,selector) then out~append(.InstrumentationCodec~copyValue(event))
  end
  return out

::method deriveSnapshotEvents
  use strict arg previous,current,publisherId,sequence
  out=.array~new
  if previous==.nil then return out
  oldHealth=.InstrumentationCodec~value(previous,"health",.InstrumentationHealth~UNKNOWN)
  newHealth=.InstrumentationCodec~value(current,"health",.InstrumentationHealth~UNKNOWN)
  if oldHealth<>newHealth then do
    ref=.InstrumentationCodec~value(current,"semantic_ref",.InstrumentationCodec~semanticRef(current["identity"]))
    evidence=.directory~new
    evidence["old_health"]=oldHealth
    evidence["new_health"]=newHealth
    evidence["publisher_id"]=publisherId
    evidence["publication_sequence"]=sequence
    severity=.InstrumentationEventSeverity~INFO
    if newHealth=.InstrumentationHealth~DEGRADED then severity=.InstrumentationEventSeverity~WARNING
    if newHealth=.InstrumentationHealth~FAILED then severity=.InstrumentationEventSeverity~ERROR
    eventId="derived-health:"||publisherId||":"||sequence||":"||ref
    out~append(.InstrumentationCodec~event(eventId,"HEALTH_CHANGED",ref,"INSTRUMENTATION_OBSERVER",.InstrumentationCodec~value(current,"observed_at",""),severity,"","","",.array~new,evidence,.nil,.true))
  end
  return out

::method deriveRelationshipEvents
  use strict arg previous,current,publisherId,sequence
  out=.array~new
  if previous==.nil then return out
  if \.InstrumentationCodec~value(previous,"complete",.false) then return out
  if \.InstrumentationCodec~value(current,"complete",.false) then return out
  oldById=.directory~new
  newById=.directory~new
  do relationship over previous["relationships"]; oldById[.InstrumentationCodec~value(relationship,"relationship_id","")]=relationship; end
  do relationship over current["relationships"]; newById[.InstrumentationCodec~value(relationship,"relationship_id","")]=relationship; end
  do id over newById
    if oldById[id]<>.nil then iterate
    relationship=newById[id]
    out~append(self~relationshipVisibilityEvent("RELATIONSHIP_BECAME_VISIBLE",relationship,current,publisherId,sequence))
  end
  do id over oldById
    if newById[id]<>.nil then iterate
    relationship=oldById[id]
    out~append(self~relationshipVisibilityEvent("RELATIONSHIP_CEASED_VISIBLE",relationship,current,publisherId,sequence))
  end
  return out

::method relationshipVisibilityEvent
  use strict arg kind,relationship,relationshipSet,publisherId,sequence
  sourceRef=.InstrumentationCodec~value(relationship,"from_ref","")
  targetRef=.InstrumentationCodec~value(relationship,"to_ref","")
  related=.array~new; if targetRef<>"" then related~append(targetRef)
  evidence=.directory~new
  evidence["source_authority"]=.InstrumentationCodec~value(relationship,"authority","")
  evidence["scope_id"]=.InstrumentationCodec~value(relationshipSet,"scope_id","")
  evidence["relationship_id"]=.InstrumentationCodec~value(relationship,"relationship_id","")
  evidence["relationship_kind"]=.InstrumentationCodec~value(relationship,"kind","")
  evidence["publisher_id"]=publisherId
  evidence["publication_sequence"]=sequence
  eventId="derived-relationship:"||publisherId||":"||sequence||":"||kind||":"||evidence["relationship_id"]
  return .InstrumentationCodec~event(eventId,kind,sourceRef,"INSTRUMENTATION_OBSERVER",.InstrumentationCodec~value(relationshipSet,"observed_at",""),.InstrumentationEventSeverity~NOTICE,"","","",related,evidence,.nil,.true)

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

::method validRelationship
  use strict arg relationship
  if relationship==.nil | \relationship~isA(.Directory) then return .false
  if .InstrumentationCodec~value(relationship,"schema","")<>.InstrumentationContract~RELATIONSHIP_SCHEMA then return .false
  if .InstrumentationCodec~value(relationship,"api","")<>.InstrumentationContract~API then return .false
  if .InstrumentationCodec~value(relationship,"relationship_id","")="" then return .false
  if .InstrumentationCodec~value(relationship,"kind","")="" then return .false
  if .InstrumentationCodec~value(relationship,"from_ref","")="" then return .false
  if .InstrumentationCodec~value(relationship,"to_ref","")="" then return .false
  if .InstrumentationCodec~value(relationship,"authority","")="" then return .false
  state=.InstrumentationCodec~value(relationship,"state","")
  if state<>"PRESENT" then if state<>"WITHDRAWN" then return .false
  return .true

::method validRelationshipSet
  use strict arg relationshipSet
  if relationshipSet==.nil | \relationshipSet~isA(.Directory) then return .false
  if .InstrumentationCodec~value(relationshipSet,"schema","")<>.InstrumentationContract~RELATIONSHIP_SET_SCHEMA then return .false
  if .InstrumentationCodec~value(relationshipSet,"api","")<>.InstrumentationContract~API then return .false
  if .InstrumentationCodec~value(relationshipSet,"scope_id","")="" then return .false
  if .InstrumentationCodec~value(relationshipSet,"authority","")="" then return .false
  relationships=relationshipSet["relationships"]
  if relationships==.nil | \relationships~isA(.Array) then return .false
  do relationship over relationships
    if \self~validRelationship(relationship) then return .false
  end
  return .true

::method latestRelationshipSets
  expose latestRelationshipSets
  use strict arg selector=.nil
  out=.array~new
  do key over latestRelationshipSets
    relationshipSet=latestRelationshipSets[key]
    if .InstrumentationSelection~relationshipSetMatches(relationshipSet,selector) then out~append(.InstrumentationCodec~copyValue(relationshipSet))
  end
  return out

::method latestRelationships
  expose latestRelationshipSets
  use strict arg selector=.nil
  out=.array~new
  do key over latestRelationshipSets
    relationshipSet=latestRelationshipSets[key]
    setSelector=.directory~new
    if selector<>.nil then do
      if selector["scope_id"]<>.nil then setSelector["scope_id"]=selector["scope_id"]
      if selector["set_authority"]<>.nil then setSelector["set_authority"]=selector["set_authority"]
      if selector["complete"]<>.nil then setSelector["complete"]=selector["complete"]
    end
    if \.InstrumentationSelection~relationshipSetMatches(relationshipSet,setSelector) then iterate
    do relationship over relationshipSet["relationships"]
      if .InstrumentationSelection~relationshipMatches(relationship,selector) then do
        copy=.InstrumentationCodec~copyValue(relationship)
        copy["scope_id"]=.InstrumentationCodec~value(relationshipSet,"scope_id","")
        copy["set_authority"]=.InstrumentationCodec~value(relationshipSet,"authority","")
        copy["complete"]=.InstrumentationCodec~value(relationshipSet,"complete",.false)
        if .InstrumentationCodec~value(copy,"observed_at","")="" then copy["observed_at"]=.InstrumentationCodec~value(relationshipSet,"observed_at","")
        out~append(copy)
      end
    end
  end
  return out

::method relationshipSetHistory
  expose relationshipHistories
  use strict arg selector=.nil,limit=0
  out=.array~new
  do key over relationshipHistories
    history=relationshipHistories[key]
    start=1
    if datatype(limit,"W") then do
      if limit>0 then if history~items>limit then start=history~items-limit+1
    end
    do i=start to history~items
      relationshipSet=history[i]
      if .InstrumentationSelection~relationshipSetMatches(relationshipSet,selector) then out~append(.InstrumentationCodec~copyValue(relationshipSet))
    end
  end
  return out

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

::method publicationEvidence
  expose latestByKey publicationEvidenceByKey
  use strict arg semanticRef
  do key over latestByKey
    snapshot=latestByKey[key]
    if .InstrumentationCodec~value(snapshot,"semantic_ref",.InstrumentationCodec~semanticRef(snapshot["identity"]))=semanticRef then do
      evidence=publicationEvidenceByKey[key]
      if evidence==.nil then return .nil
      return .InstrumentationCodec~copyValue(evidence)
    end
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
    when mode="RELATIONSHIPS_LATEST" then payload=self~latestRelationships(selector)
    when mode="RELATIONSHIP_SETS_LATEST" then payload=self~latestRelationshipSets(selector)
    when mode="RELATIONSHIP_SETS_HISTORY" then payload=self~relationshipSetHistory(selector,limit)
    when mode="EVENTS" | mode="EVENTS_HISTORY" then payload=self~eventsHistory(selector,limit)
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
  use strict arg observedAt="",publishedPosixSeconds=.nil
  snapshots=service~sampleAll(observedAt)
  relationshipSets=service~sampleRelationships(observedAt)
  events=service~sampleEvents(observedAt)
  sequence+=1
  publicationId=publisherId||"-"||sequence
  publication=.InstrumentationCodec~publication(publicationId,publisherId,sequence,snapshots,observedAt,publishedPosixSeconds,relationshipSets,events)
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
