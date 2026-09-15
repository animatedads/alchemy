/* ooRexx Observation v0.5 */
::class ObservationBuild public
::constant RELEASE "0.5"
::constant API_VERSION "observation.readonly/0.5"

::class ObservationValidation public
::attribute ok get
::attribute code get
::attribute message get
::attribute missingMethods get
::method init
  expose ok code message missingMethods
  use arg okArg, codeArg="OK", messageArg="", missingArg=.nil
  ok=okArg==.true; code=codeArg~string; message=messageArg~string
  missingMethods=.array~new
  if missingArg<>.nil then do item over missingArg; missingMethods~append(item~string); end

::class ObservationEnvelope public
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::attribute capturedGeneration get
::attribute snapshot get
::method init
  expose sessionId terminalType deviceName capturedGeneration snapshot
  use arg sessionIdArg,typeArg,deviceArg,snapshotArg
  sessionId=sessionIdArg~string; terminalType=typeArg~string; deviceName=deviceArg~string
  if snapshotArg==.nil then do; capturedGeneration=0; snapshot=.nil; end
  else do
    capturedGeneration=snapshotArg~generation
    if snapshotArg~hasMethod("COPYDETACHED") then snapshot=snapshotArg~copyDetached
    else snapshot=snapshotArg
  end
::method copyDetached
  expose sessionId terminalType deviceName snapshot
  return .ObservationEnvelope~new(sessionId,terminalType,deviceName,snapshot)

::class ObservationProtocol public
::method requiredSessionMethods class public
  return .array~of("SESSIONID","TERMINALTYPE","DEVICENAME","SNAPSHOT","CURRENT","BACK","HISTORY","KNOWNSTATESTATUS","KNOWNSTATEID","KNOWNSTATEGENERATION","KNOWNSTATEHISTORY")
::method requiredSnapshotMethods class public
  return .array~of("GENERATION","TERMINALTYPE","VISIBLETEXT","CONTENTDIGEST","COPYDETACHED")
::method validateObserver class public
  use arg observer
  missing=.array~new
  if observer==.nil then return .ObservationValidation~new(.false,"OBSERVER_MISSING","observer is nil",self~requiredSessionMethods)
  do methodName over self~requiredSessionMethods
    if \observer~hasMethod(methodName) then missing~append(methodName)
  end
  if missing~items>0 then return .ObservationValidation~new(.false,"OBSERVER_CONTRACT_INVALID","observer is missing required read-only observation methods",missing)
  snap=observer~snapshot
  if snap<>.nil then do
    do methodName over self~requiredSnapshotMethods
      if \snap~hasMethod(methodName) then missing~append("SNAPSHOT."||methodName)
    end
  end
  if missing~items>0 then return .ObservationValidation~new(.false,"SNAPSHOT_CONTRACT_INVALID","snapshot is missing required detached observation methods",missing)
  return .ObservationValidation~new(.true)
::method capture class public
  use arg observer
  checked=self~validateObserver(observer)
  if \checked~ok then return .nil
  return .ObservationEnvelope~new(observer~sessionId,observer~terminalType,observer~deviceName,observer~snapshot)

::class ObservationCheckpoint public
::attribute streamId get
::attribute sequence get
::attribute sessionId get
::attribute generation get
::method init
  expose streamId sequence sessionId generation
  use arg streamIdArg,sequenceArg,sessionIdArg,generationArg
  streamId=streamIdArg~string; sequence=sequenceArg+0; sessionId=sessionIdArg~string; generation=generationArg+0
::method copyDetached
  expose streamId sequence sessionId generation
  return .ObservationCheckpoint~new(streamId,sequence,sessionId,generation)

::class ObservationStreamRecord public
::attribute streamId get
::attribute sequence get
::attribute kind get
::attribute envelope get
::method init
  expose streamId sequence kind envelope
  use arg streamIdArg,sequenceArg,kindArg,envelopeArg
  streamId=streamIdArg~string; sequence=sequenceArg+0; kind=kindArg~string
  if envelopeArg==.nil then envelope=.nil; else envelope=envelopeArg~copyDetached
::method generation
  expose envelope
  if envelope==.nil then return 0
  return envelope~capturedGeneration
::method copyDetached
  expose streamId sequence kind envelope
  return .ObservationStreamRecord~new(streamId,sequence,kind,envelope)

::class ObservationSubscription public
::attribute subscriptionId get
::attribute streamId get
::attribute nextSequence
::attribute active
::attribute credit
::attribute maxCredit get
::method init
  expose subscriptionId streamId nextSequence active credit maxCredit
  use arg idArg,streamArg,nextArg=1,creditArg=64
  subscriptionId=idArg~string; streamId=streamArg~string; nextSequence=nextArg+0; active=.true
  maxCredit=creditArg+0; if maxCredit<1 then maxCredit=1; credit=maxCredit
::method ack
  expose credit maxCredit
  use arg countArg=1
  credit=credit+(countArg+0); if credit>maxCredit then credit=maxCredit; if credit<0 then credit=0
  return credit

::class ObservationStream public
::attribute streamId get
::attribute observer get
::method init
  expose streamId observer records nextSequence nextSubscriber retentionLimit
  use arg idArg,observerArg,retentionArg=256
  checked=.ObservationProtocol~validateObserver(observerArg)
  if \checked~ok then raise syntax 93.900 array("invalid observation source:" checked~code)
  streamId=idArg~string; observer=observerArg; records=.array~new; nextSequence=1; nextSubscriber=1; retentionLimit=retentionArg+0; if retentionLimit<1 then retentionLimit=1
::method publish
  expose streamId observer records nextSequence retentionLimit
  use arg kind="SNAPSHOT"
  env=.ObservationProtocol~capture(observer)
  if env==.nil then return .nil
  if records~items>0 then do
    prior=records[records~items]
    if prior~generation=env~capturedGeneration then return prior~copyDetached
  end
  rec=.ObservationStreamRecord~new(streamId,nextSequence,kind,env)
  records~append(rec); nextSequence+=1
  do while records~items>retentionLimit; records~remove(1); end
  return rec~copyDetached
::method subscribe
  expose streamId nextSubscriber nextSequence
  use arg checkpoint=.nil,creditArg=64
  start=1
  if checkpoint<>.nil then do
    if checkpoint~streamId<>streamId then raise syntax 93.900 array("checkpoint stream mismatch")
    start=checkpoint~sequence+1
  end
  id=streamId||"-SUB-"||nextSubscriber; nextSubscriber+=1
  return .ObservationSubscription~new(id,streamId,start,creditArg)
::method read
  expose streamId records
  use arg subscription,maxItems=100
  out=.array~new
  if subscription==.nil | \subscription~active then return out
  if subscription~streamId<>streamId then return out
  if subscription~credit<=0 then return out
  allowed=maxItems+0; if allowed>subscription~credit then allowed=subscription~credit; if allowed<1 then return out
  do rec over records
    if rec~sequence>=subscription~nextSequence then do
      out~append(rec~copyDetached)
      subscription~nextSequence=rec~sequence+1
      subscription~credit=subscription~credit-1
      if out~items>=allowed then leave
    end
  end
  return out
::method checkpoint
  expose streamId observer
  use arg sequence=.nil
  if sequence==.nil then sequence=0
  gen=0; snap=observer~snapshot; if snap<>.nil then gen=snap~generation
  return .ObservationCheckpoint~new(streamId,sequence,observer~sessionId,gen)
::method latestCheckpoint
  expose streamId records observer
  seq=0; gen=0
  if records~items>0 then do; seq=records[records~items]~sequence; gen=records[records~items]~generation; end
  return .ObservationCheckpoint~new(streamId,seq,observer~sessionId,gen)

::class ObservationDelta public
::attribute fromGeneration get
::attribute toGeneration get
::attribute kind get
::attribute visibleText get
::method init
  expose fromGeneration toGeneration kind visibleText
  use arg fromArg,toArg,kindArg,textArg=""
  fromGeneration=fromArg+0; toGeneration=toArg+0; kind=kindArg~string; visibleText=textArg~string
::method copyDetached
  expose fromGeneration toGeneration kind visibleText
  return .ObservationDelta~new(fromGeneration,toGeneration,kind,visibleText)

::class ObservationDeltaBuilder public
::method between class public
  use arg previous,current
  if current==.nil then return .ObservationDelta~new(0,0,"EMPTY","")
  if previous==.nil then return .ObservationDelta~new(0,current~generation,"INITIAL",current~visibleText)
  if previous~contentDigest=current~contentDigest then return .ObservationDelta~new(previous~generation,current~generation,"UNCHANGED","")
  return .ObservationDelta~new(previous~generation,current~generation,"CHANGED",current~visibleText)

::class ObservationReadResult public
::attribute ok get
::attribute code get
::attribute records get
::attribute oldestSequence get
::attribute nextSequence get
::method init
  expose ok code records oldestSequence nextSequence
  use arg okArg,codeArg,recordsArg=.nil,oldestArg=0,nextArg=0
  ok=okArg==.true; code=codeArg~string; oldestSequence=oldestArg+0; nextSequence=nextArg+0
  records=.array~new
  if recordsArg<>.nil then do r over recordsArg; records~append(r~copyDetached); end

::class ObservationGatewayLease public
::attribute leaseId get
::attribute principalId get
::attribute streamId get
::attribute subscription get
::attribute expiresAt
::attribute lastHeartbeat
::attribute active
::method init
  expose leaseId principalId streamId subscription expiresAt lastHeartbeat active
  use arg leaseArg,principalArg,streamArg,subscriptionArg,expiresArg,nowArg
  leaseId=leaseArg~string; principalId=principalArg~string; streamId=streamArg~string; subscription=subscriptionArg; expiresAt=expiresArg+0; lastHeartbeat=nowArg+0; active=.true

::class ObservationGatewayResult public
::attribute ok get
::attribute code get
::attribute value get
::method init
  expose ok code value
  use arg okArg,codeArg,valueArg=.nil
  ok=okArg==.true; code=codeArg~string; value=valueArg

/* Neutral, transport-independent service boundary.  Time is supplied by the caller
   so tests and higher-level schedulers can use their own monotonic clock. */
::class ObservationGateway public
::method init
  expose streams grants leases nextLease defaultTtl authorizer
  use arg ttlArg=60,authorizerArg=.nil
  streams=.directory~new; grants=.directory~new; leases=.directory~new; nextLease=1; defaultTtl=ttlArg+0; if defaultTtl<1 then defaultTtl=60
  authorizer=authorizerArg
::method registerStream
  expose streams
  use arg stream
  if stream==.nil then return .ObservationGatewayResult~new(.false,"STREAM_MISSING")
  streams[stream~streamId]=stream
  return .ObservationGatewayResult~new(.true,"OK",stream~streamId)
::method grant
  expose grants
  use arg principalId,streamId
  key=principalId~string||"|"||streamId~string; grants[key]=.true
  return .ObservationGatewayResult~new(.true,"OK")
::method revokeGrant
  expose grants
  use arg principalId,streamId
  key=principalId~string||"|"||streamId~string
  if grants~hasIndex(key) then grants~remove(key)
  return .ObservationGatewayResult~new(.true,"OK")
::method authorised private
  expose grants authorizer
  use arg principalId,streamId
  if authorizer<>.nil then return authorizer~mayObserve(principalId~string,streamId~string)
  return grants~hasIndex(principalId~string||"|"||streamId~string)
::method subscribe
  expose streams leases nextLease defaultTtl
  use arg principalId,streamId,nowArg=0,ttlArg=.nil,checkpoint=.nil,creditArg=64
  if \self~authorised(principalId,streamId) then return .ObservationGatewayResult~new(.false,"OBSERVATION_ACCESS_DENIED")
  if \streams~hasIndex(streamId~string) then return .ObservationGatewayResult~new(.false,"STREAM_NOT_FOUND")
  ttl=defaultTtl; if ttlArg<>.nil then ttl=ttlArg+0; if ttl<1 then ttl=defaultTtl
  stream=streams[streamId~string]
  sub=stream~subscribe(checkpoint,creditArg)
  id="OBSLEASE-"||nextLease; nextLease+=1
  lease=.ObservationGatewayLease~new(id,principalId,streamId,sub,nowArg+ttl,nowArg)
  leases[id]=lease
  return .ObservationGatewayResult~new(.true,"OK",lease)
::method validateLease private
  expose leases
  use arg lease,nowArg=0
  if lease==.nil then return .ObservationGatewayResult~new(.false,"OBSERVATION_LEASE_MISSING")
  if \leases~hasIndex(lease~leaseId) then return .ObservationGatewayResult~new(.false,"OBSERVATION_LEASE_UNKNOWN")
  known=leases[lease~leaseId]
  if \known~active then return .ObservationGatewayResult~new(.false,"OBSERVATION_LEASE_REVOKED")
  if nowArg+0>known~expiresAt then do; known~active=.false; return .ObservationGatewayResult~new(.false,"OBSERVATION_LEASE_EXPIRED"); end
  return .ObservationGatewayResult~new(.true,"OK",known)
::method heartbeat
  use arg lease,nowArg=0,ttlArg=.nil
  checked=self~validateLease(lease,nowArg); if \checked~ok then return checked
  known=checked~value; ttl=known~expiresAt-known~lastHeartbeat; if ttlArg<>.nil then ttl=ttlArg+0; if ttl<1 then ttl=60
  known~lastHeartbeat=nowArg+0; known~expiresAt=nowArg+ttl
  return .ObservationGatewayResult~new(.true,"OK",known)
::method read
  expose streams
  use arg lease,nowArg=0,maxItems=100
  checked=self~validateLease(lease,nowArg); if \checked~ok then return checked
  known=checked~value; stream=streams[known~streamId]
  records=stream~read(known~subscription,maxItems)
  return .ObservationGatewayResult~new(.true,"OK",records)
::method ack
  use arg lease,countArg=1,nowArg=0
  checked=self~validateLease(lease,nowArg); if \checked~ok then return checked
  return .ObservationGatewayResult~new(.true,"OK",checked~value~subscription~ack(countArg))
::method query
  expose streams
  use arg lease,query,nowArg=0
  checked=self~validateLease(lease,nowArg); if \checked~ok then return checked
  known=checked~value; stream=streams[known~streamId]
  return .ObservationGatewayResult~new(.true,"OK",.ObservationQueryRouter~new~execute(stream~observer,query))
::method revokeLease
  use arg lease
  if lease<>.nil then lease~active=.false
  return .ObservationGatewayResult~new(.true,"OK")

::class ObservationQueryEnvelope public
::attribute requestId get
::attribute operation get
::attribute argument get
::method init
  expose requestId operation argument
  use arg idArg,operationArg,argumentArg=.nil
  requestId=idArg~string; operation=operationArg~string~upper; argument=argumentArg
::method isReadOnly
  expose operation
  return operation="SNAPSHOT" | operation="CURRENT" | operation="BACK" | operation="HISTORY" | operation="KNOWN_STATE"

::class ObservationQueryResult public
::attribute ok get
::attribute code get
::attribute requestId get
::attribute value get
::method init
  expose ok code requestId value
  use arg okArg,codeArg,idArg,valueArg=.nil
  ok=okArg==.true; code=codeArg~string; requestId=idArg~string; value=valueArg

::class ObservationQueryRouter public
::method execute
  use arg observer,query
  checked=.ObservationProtocol~validateObserver(observer)
  if \checked~ok then return .ObservationQueryResult~new(.false,checked~code,query~requestId)
  if \query~isReadOnly then return .ObservationQueryResult~new(.false,"OBSERVATION_MUTATION_FORBIDDEN",query~requestId)
  op=query~operation
  if op="SNAPSHOT" then return .ObservationQueryResult~new(.true,"OK",query~requestId,observer~snapshot)
  if op="CURRENT" then return .ObservationQueryResult~new(.true,"OK",query~requestId,observer~current)
  if op="BACK" then do; n=query~argument; if n==.nil then n=1; return .ObservationQueryResult~new(.true,"OK",query~requestId,observer~back(n)); end
  if op="HISTORY" then return .ObservationQueryResult~new(.true,"OK",query~requestId,observer~history)
  if op="KNOWN_STATE" then do
    d=.directory~new; d["status"]=observer~knownStateStatus; d["id"]=observer~knownStateId; d["generation"]=observer~knownStateGeneration; d["history"]=observer~knownStateHistory
    return .ObservationQueryResult~new(.true,"OK",query~requestId,d)
  end
  return .ObservationQueryResult~new(.false,"OBSERVATION_QUERY_UNKNOWN",query~requestId)


::class ObservationStructuralChange public
::attribute kind get
::attribute key get
::attribute beforeValue get
::attribute afterValue get
::method init
  expose kind key beforeValue afterValue
  use arg kindArg,keyArg,beforeArg="",afterArg=""
  kind=kindArg~string~upper; key=keyArg~string; beforeValue=beforeArg~string; afterValue=afterArg~string
::method copyDetached
  expose kind key beforeValue afterValue
  return .ObservationStructuralChange~new(kind,key,beforeValue,afterValue)

::class ObservationStructuralDelta public
::attribute fromGeneration get
::attribute toGeneration get
::attribute changes get
::method init
  expose fromGeneration toGeneration changes
  use arg fromArg,toArg,changesArg=.nil
  fromGeneration=fromArg+0; toGeneration=toArg+0; changes=.array~new
  if changesArg<>.nil then do c over changesArg; changes~append(c~copyDetached); end
::method count
  expose changes
  return changes~items
::method copyDetached
  expose fromGeneration toGeneration changes
  return .ObservationStructuralDelta~new(fromGeneration,toGeneration,changes)

::class ObservationStructuralDeltaBuilder public
::method rows private class
  use arg snap
  out=.array~new
  if snap==.nil then return out
  if snap~hasMethod("TEXTROWS") then return snap~textRows
  txt=snap~visibleText; do while txt<>""; parse var txt line "0a"x txt; out~append(line); end
  return out
::method fieldMap private class
  use arg snap
  d=.directory~new
  if snap==.nil | \snap~hasMethod("FIELDS") then return d
  do f over snap~fields
    key=f~fieldId~string
    value=""
    if f~hasMethod("DISPLAYVALUE") then value=f~displayValue; else if f~hasMethod("VALUE") then value=f~value
    d[key]=value
  end
  return d
::method between class public
  use arg previous,current
  fromGen=0; toGen=0; if previous<>.nil then fromGen=previous~generation; if current<>.nil then toGen=current~generation
  changes=.array~new
  before=self~rows(previous); after=self~rows(current); max=before~items; if after~items>max then max=after~items
  do i=1 to max
    b=""; a=""; if i<=before~items then b=before[i]; if i<=after~items then a=after[i]
    if i>before~items then changes~append(.ObservationStructuralChange~new("ROW_ADDED",i,"",a))
    else if i>after~items then changes~append(.ObservationStructuralChange~new("ROW_REMOVED",i,b,""))
    else if b<>a then changes~append(.ObservationStructuralChange~new("ROW_CHANGED",i,b,a))
  end
  bf=self~fieldMap(previous); af=self~fieldMap(current)
  do k over bf
    if \af~hasIndex(k) then changes~append(.ObservationStructuralChange~new("FIELD_REMOVED",k,bf[k],""))
    else if bf[k]<>af[k] then changes~append(.ObservationStructuralChange~new("FIELD_CHANGED",k,bf[k],af[k]))
  end
  do k over af
    if \bf~hasIndex(k) then changes~append(.ObservationStructuralChange~new("FIELD_ADDED",k,"",af[k]))
  end
  return .ObservationStructuralDelta~new(fromGen,toGen,changes)

/* Security integration seam. Production implementations bind this to the common
   Access Control + Permissions + Security Effect authority, not a new trust model. */
::class ObservationAuthorizer public
::method mayObserve abstract

/* Primitive transport envelope designed for Queue Fabric payload codecs. */
::class ObservationTransportEnvelope public
::attribute streamId get
::attribute sequence get
::attribute sessionId get
::attribute terminalType get
::attribute generation get
::attribute kind get
::attribute visibleText get
::method init
  expose streamId sequence sessionId terminalType generation kind visibleText
  use arg streamArg,seqArg,sessionArg,typeArg,genArg,kindArg,textArg
  streamId=streamArg~string; sequence=seqArg+0; sessionId=sessionArg~string; terminalType=typeArg~string; generation=genArg+0; kind=kindArg~string; visibleText=textArg~string
::method asTable
  expose streamId sequence sessionId terminalType generation kind visibleText
  t=.table~new; t["schema"]="observation.stream/0.5"; t["streamId"]=streamId; t["sequence"]=sequence; t["sessionId"]=sessionId; t["terminalType"]=terminalType; t["generation"]=generation; t["kind"]=kind; t["visibleText"]=visibleText; return t
::method fromRecord class public
  use arg rec
  env=rec~envelope; text=""; sid=""; typ=""; if env<>.nil then do; sid=env~sessionId; typ=env~terminalType; if env~snapshot<>.nil then text=env~snapshot~visibleText; end
  return .ObservationTransportEnvelope~new(rec~streamId,rec~sequence,sid,typ,rec~generation,rec~kind,text)

/* Adapter to Queue Fabric's stable ObjectQueueManager~put(queue,payload,options,principal)
   boundary. Observation owns no Queue Fabric lifecycle or routing policy. */
::class ObservationQueueFabricAdapter public
::method init
  expose queueManager queueName principal
  use arg managerArg,queueArg,principalArg=""
  queueManager=managerArg; queueName=queueArg~string; principal=principalArg~string
::method publishRecord
  expose queueManager queueName principal
  use arg record,options=.nil
  if record==.nil then return .nil
  payload=.ObservationTransportEnvelope~fromRecord(record)~asTable
  if options==.nil then options=.table~new
  options["correlationId"]=record~streamId||":"||record~sequence
  return queueManager~put(queueName,payload,options,principal)

::class SemanticObservationMonitor public
::method validate
  use arg observer
  return .ObservationProtocol~validateObserver(observer)
::method capture
  use arg observer
  return .ObservationProtocol~capture(observer)
::method render
  use arg observer
  checked=self~validate(observer)
  if \checked~ok then return "Observation unavailable: "||checked~code
  snap=observer~snapshot
  if snap==.nil then return "Session: "||observer~sessionId||"0a"x||"No observation"
  out="Session: "||observer~sessionId||"0a"x||"Type: "||observer~terminalType||"0a"x||"Device: "||observer~deviceName||"0a"x||"Generation: "||snap~generation||"0a"x
  return out||snap~visibleText
::method delta
  use arg observer
  checked=self~validate(observer)
  if \checked~ok then return "OBSERVATION_INVALID "||checked~code
  current=observer~current; previous=observer~back(1)
  if current==.nil then return ""
  if previous==.nil then return "GENERATION "||current~generation||" INITIAL"||"0a"x||current~visibleText
  if current~contentDigest=previous~contentDigest then return "GENERATION "||current~generation||" UNCHANGED"
  return "GENERATION "||previous~generation||" -> "||current~generation||" CHANGED"||"0a"x||current~visibleText


/* Observation Queue Service v0.5.  This layer owns observation producer/consumer
   coordination.  Queue Fabric still owns queue transport and WLU remains an
   independently supplied admission authority. */
::class ObservationProducerRegistration public
::attribute producerId get
::attribute nodeId get
::attribute proofRef get
::attribute capabilityGeneration get
::attribute active
::method init
  expose producerId nodeId proofRef capabilityGeneration active
  use arg producerArg,nodeArg,proofArg="",generationArg=0
  producerId=producerArg~string; nodeId=nodeArg~string; proofRef=proofArg~string; capabilityGeneration=generationArg+0; active=.true

::class ObservationStreamDescriptor public
::attribute streamId get
::attribute producerId get
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::attribute nodeId get
::attribute proofRef get
::attribute capabilityGeneration get
::method init
  expose streamId producerId sessionId terminalType deviceName nodeId proofRef capabilityGeneration
  use arg streamArg,producerArg,sessionArg,typeArg,deviceArg,nodeArg,proofArg="",generationArg=0
  streamId=streamArg~string; producerId=producerArg~string; sessionId=sessionArg~string; terminalType=typeArg~string; deviceName=deviceArg~string; nodeId=nodeArg~string; proofRef=proofArg~string; capabilityGeneration=generationArg+0

::class ObservationConsumerCheckpoint public
::attribute consumerId get
::attribute streamId get
::attribute sequence get
::attribute generation get
::attribute updatedAt get
::method init
  expose consumerId streamId sequence generation updatedAt
  use arg consumerArg,streamArg,sequenceArg=0,generationArg=0,updatedArg=0
  consumerId=consumerArg~string; streamId=streamArg~string; sequence=sequenceArg+0; generation=generationArg+0; updatedAt=updatedArg+0
::method copyDetached
  expose consumerId streamId sequence generation updatedAt
  return .ObservationConsumerCheckpoint~new(consumerId,streamId,sequence,generation,updatedAt)

::class ObservationReplayRequest public
::attribute requestId get
::attribute consumerId get
::attribute streamId get
::attribute afterSequence get
::attribute maxItems get
::method init
  expose requestId consumerId streamId afterSequence maxItems
  use arg requestArg,consumerArg,streamArg,afterArg=0,maxArg=100
  requestId=requestArg~string; consumerId=consumerArg~string; streamId=streamArg~string; afterSequence=afterArg+0; maxItems=maxArg+0; if maxItems<1 then maxItems=1

::class ObservationServiceResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute retryAfterSeconds get
::method init
  expose ok code value retryAfterSeconds
  use arg okArg,codeArg,valueArg=.nil,retryArg=0
  ok=okArg==.true; code=codeArg~string; value=valueArg; retryAfterSeconds=retryArg

/* Optional WLU adapter.  It intentionally duck-types WLUCapacityBucket so this
   package has no compile-time dependency on a particular WLU release. */
::class ObservationWLUDeliveryAdmission public
::attribute costMicroWlu get
::method init
  expose bucket costMicroWlu
  use arg bucketArg,costArg=1000000
  bucket=bucketArg; costMicroWlu=costArg+0
::method admit
  expose bucket costMicroWlu
  use arg principalId,streamId,record,nowArg=0
  if bucket==.nil then return .ObservationServiceResult~new(.true,"OK")
  if bucket~hold(costMicroWlu,nowArg) then return .ObservationServiceResult~new(.true,"OK")
  retry=bucket~retryAfterSeconds(costMicroWlu,nowArg)
  return .ObservationServiceResult~new(.false,"OBSERVATION_WLU_THROTTLED",.nil,retry)
::method settle
  expose bucket costMicroWlu
  use arg actualMicroWlu=.nil,nowArg=0
  if bucket==.nil then return .true
  actual=costMicroWlu; if actualMicroWlu<>.nil then actual=actualMicroWlu+0
  return bucket~settleHold(costMicroWlu,actual,nowArg)

::class ObservationQueueService public
::method init
  expose queueManager queueName principal producers streams descriptors checkpoints deliveryAdmission authorizer
  use arg managerArg=.nil,queueArg="",principalArg="",admissionArg=.nil,authorizerArg=.nil
  queueManager=managerArg; queueName=queueArg~string; principal=principalArg~string; deliveryAdmission=admissionArg; authorizer=authorizerArg
  producers=.directory~new; streams=.directory~new; descriptors=.directory~new; checkpoints=.directory~new
::method registerProducer
  expose producers
  use arg producer
  if producer==.nil then return .ObservationServiceResult~new(.false,"PRODUCER_MISSING")
  producers[producer~producerId]=producer
  return .ObservationServiceResult~new(.true,"OK",producer)
::method registerStream
  expose producers streams descriptors
  use arg producerId,stream,nodeId="",proofRef="",capabilityGeneration=0
  if \producers~hasIndex(producerId~string) then return .ObservationServiceResult~new(.false,"PRODUCER_NOT_REGISTERED")
  producer=producers[producerId~string]
  if \producer~active then return .ObservationServiceResult~new(.false,"PRODUCER_INACTIVE")
  if stream==.nil then return .ObservationServiceResult~new(.false,"STREAM_MISSING")
  streams[stream~streamId]=stream
  obs=stream~observer
  effectiveNode=nodeId~string; if effectiveNode="" then effectiveNode=producer~nodeId
  effectiveProof=proofRef~string; if effectiveProof="" then effectiveProof=producer~proofRef
  effectiveGen=capabilityGeneration+0; if effectiveGen=0 then effectiveGen=producer~capabilityGeneration
  d=.ObservationStreamDescriptor~new(stream~streamId,producer~producerId,obs~sessionId,obs~terminalType,obs~deviceName,effectiveNode,effectiveProof,effectiveGen)
  descriptors[stream~streamId]=d
  return .ObservationServiceResult~new(.true,"OK",d)
::method descriptor
  expose descriptors
  use arg streamId
  if \descriptors~hasIndex(streamId~string) then return .nil
  return descriptors[streamId~string]
::method discover
  expose descriptors
  use arg terminalType="",nodeId=""
  out=.array~new; typeFilter=terminalType~string~upper; nodeFilter=nodeId~string
  do id over descriptors
    d=descriptors[id]
    if typeFilter<>"" & d~terminalType~upper<>typeFilter then iterate
    if nodeFilter<>"" & d~nodeId<>nodeFilter then iterate
    out~append(d)
  end
  return out
::method authorised private
  expose authorizer
  use arg consumerId,streamId
  if authorizer==.nil then return .true
  return authorizer~mayObserve(consumerId~string,streamId~string)
::method checkpointKey private
  use arg consumerId,streamId
  return consumerId~string||"|"||streamId~string
::method checkpoint
  expose checkpoints
  use arg consumerId,streamId
  key=self~checkpointKey(consumerId,streamId)
  if \checkpoints~hasIndex(key) then return .ObservationConsumerCheckpoint~new(consumerId,streamId,0,0,0)
  return checkpoints[key]~copyDetached
::method commitCheckpoint
  expose checkpoints
  use arg consumerId,streamId,sequence,generation=0,nowArg=0
  key=self~checkpointKey(consumerId,streamId)
  prior=self~checkpoint(consumerId,streamId)
  if sequence+0<prior~sequence then return .ObservationServiceResult~new(.false,"CHECKPOINT_REGRESSION",prior)
  cp=.ObservationConsumerCheckpoint~new(consumerId,streamId,sequence,generation,nowArg)
  checkpoints[key]=cp
  return .ObservationServiceResult~new(.true,"OK",cp~copyDetached)
::method replay
  expose streams
  use arg request
  if request==.nil then return .ObservationServiceResult~new(.false,"REPLAY_REQUEST_MISSING")
  if \self~authorised(request~consumerId,request~streamId) then return .ObservationServiceResult~new(.false,"OBSERVATION_ACCESS_DENIED")
  if \streams~hasIndex(request~streamId) then return .ObservationServiceResult~new(.false,"STREAM_NOT_FOUND")
  cp=.ObservationCheckpoint~new(request~streamId,request~afterSequence,"",0)
  sub=streams[request~streamId]~subscribe(cp,request~maxItems)
  rows=streams[request~streamId]~read(sub,request~maxItems)
  return .ObservationServiceResult~new(.true,"OK",rows)
::method publishLatest
  expose streams deliveryAdmission queueManager queueName principal
  use arg producerId,streamId,nowArg=0,options=.nil
  if \streams~hasIndex(streamId~string) then return .ObservationServiceResult~new(.false,"STREAM_NOT_FOUND")
  d=self~descriptor(streamId)
  if d==.nil | d~producerId<>producerId~string then return .ObservationServiceResult~new(.false,"PRODUCER_STREAM_MISMATCH")
  rec=streams[streamId~string]~publish
  if rec==.nil then return .ObservationServiceResult~new(.false,"OBSERVATION_EMPTY")
  if deliveryAdmission<>.nil then do
    admitted=deliveryAdmission~admit(principal,streamId,rec,nowArg)
    if \admitted~ok then return admitted
  end
  if queueManager==.nil | queueName="" then do
    if deliveryAdmission<>.nil then ignore=deliveryAdmission~settle(.nil,nowArg)
    return .ObservationServiceResult~new(.true,"LOCAL_ONLY",rec)
  end
  adapter=.ObservationQueueFabricAdapter~new(queueManager,queueName,principal)
  qr=adapter~publishRecord(rec,options)
  if deliveryAdmission<>.nil then ignore=deliveryAdmission~settle(.nil,nowArg)
  if qr==.nil then return .ObservationServiceResult~new(.false,"QUEUE_DELIVERY_FAILED")
  if qr~hasMethod("OK") & \qr~ok then return .ObservationServiceResult~new(.false,"QUEUE_DELIVERY_FAILED",qr)
  return .ObservationServiceResult~new(.true,"OK",rec)
