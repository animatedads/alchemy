/* Memory Fabric XTP orchestration candidate (additive to Memory Fabric dev10).
 * Service names, not IP/MAC/port addresses. All byte movement and admission
 * are delegated to the real Memory Fabric and qualified XTP/native backend.
 * This source is a planning/contract layer: NO DISPATCH and NO REMOTE MUTATION.
 */

::class MemoryXtpTransferBuild public
::constant VERSION '0.1-candidate1'
::constant API 'memory.fabric.xtp-transfer/0.1'

::class MemoryXtpWindowRequest public
::method init
  expose fabricId blockId blockGeneration firstByte endByte pageBytes
  use strict arg fabricArg,blockArg,generationArg,firstArg,endArg,pageArg=2097152
  numeric digits 20
  fabricId=fabricArg~string~strip; blockId=blockArg~string~strip
  if datatype(generationArg,'W')=0 | datatype(firstArg,'W')=0 | datatype(endArg,'W')=0 | datatype(pageArg,'W')=0 then
    raise syntax 88.900 array('Memory window fields must be whole numbers')
  blockGeneration=generationArg+0; firstByte=firstArg+0; endByte=endArg+0; pageBytes=pageArg+0
  if fabricId='' | blockId='' | blockGeneration<1 then raise syntax 88.900 array('invalid fabric/block identity')
  if pageBytes<1 | firstByte<0 | endByte<=firstByte then raise syntax 88.900 array('invalid Memory window')
  if firstByte//pageBytes<>0 | endByte//pageBytes<>0 then raise syntax 88.900 array('Memory windows must be full aligned pages')
::attribute fabricId get
::attribute blockId get
::attribute blockGeneration get
::attribute firstByte get
::attribute endByte get
::attribute pageBytes get
::method pageCount
  expose firstByte endByte pageBytes
  return (endByte-firstByte)%pageBytes

::class MemoryXtpResidentOffer public
::method init
  expose fabricId blockId blockGeneration peerId providerId ownerEpoch providerGeneration firstByte endByte evidenceId
  use strict arg fabricArg,blockArg,generationArg,peerArg,providerArg,epochArg,providerGenerationArg,firstArg,endArg,evidenceArg
  numeric digits 20
  fabricId=fabricArg~string~strip; blockId=blockArg~string~strip
  peerId=peerArg~string~strip; providerId=providerArg~string~strip
  if datatype(generationArg,'W')=0 | datatype(epochArg,'W')=0 | datatype(providerGenerationArg,'W')=0 | datatype(firstArg,'W')=0 | datatype(endArg,'W')=0 then
    raise syntax 88.900 array('Memory offer fields must be whole numbers')
  blockGeneration=generationArg+0; ownerEpoch=epochArg+0; providerGeneration=providerGenerationArg+0
  firstByte=firstArg+0; endByte=endArg+0; evidenceId=evidenceArg~string~strip
  if fabricId='' | blockId='' | peerId='' | providerId='' | evidenceId='' then raise syntax 88.900 array('missing offer identity/evidence')
  if blockGeneration<1 | ownerEpoch<1 | providerGeneration<1 | firstByte<0 | endByte<=firstByte then raise syntax 88.900 array('invalid offer values')
  /* Logical peers cannot be IP endpoints; physical addressing is route-table authority. */
  if self~looksLikeIp(peerId) then raise syntax 88.900 array('Memory XTP offer requires logical peer, not IP address')
::attribute fabricId get
::attribute blockId get
::attribute blockGeneration get
::attribute peerId get
::attribute providerId get
::attribute ownerEpoch get
::attribute providerGeneration get
::attribute firstByte get
::attribute endByte get
::attribute evidenceId get
::method covers
  expose firstByte endByte
  use strict arg firstArg,endArg
  return firstByte<=firstArg & endByte>=endArg
::method looksLikeIp
  use strict arg value
  if pos(':',value)>0 | pos('[',value)>0 | pos(']',value)>0 then return .true
  if value~countstr('.')=3 then do
    rest=value; numeric=.true
    do 4
      parse var rest oct '.' rest
      if oct='' | datatype(oct,'W')=0 then numeric=.false
      else if oct<0 | oct>255 then numeric=.false
    end
    if numeric then return .true
  end
  return .false

::class MemoryXtpTransferPolicy public
::method init
  expose className state perContextCapPercent maxParallelContexts aggregateCapPercent fallback protectedOnly transmit transformRequired
  use strict arg classArg,stateArg,decision
  className=classArg~string; state=stateArg~string
  perContextCapPercent=self~whole(decision,'PER_CONTEXT_CAP_PERCENT',100)
  maxParallelContexts=self~whole(decision,'MAX_PARALLEL_CONTEXTS',1)
  aggregateCapPercent=self~whole(decision,'AGGREGATE_CAP_PERCENT',100)
  fallback=self~value(decision,'FALLBACK','forbid')
  protectedOnly=(self~whole(decision,'PROTECTED_ONLY',0)=1)
  transmit=(self~whole(decision,'TRANSMIT',0)=1)
  transformRequired=(self~whole(decision,'TRANSFORM',0)=1)
  if perContextCapPercent<1 | perContextCapPercent>100 | maxParallelContexts<1 | aggregateCapPercent<1 | aggregateCapPercent>100 then
    raise syntax 88.900 array('invalid XTP operational capacity limits')
::attribute className get
::attribute state get
::attribute perContextCapPercent get
::attribute maxParallelContexts get
::attribute aggregateCapPercent get
::attribute fallback get
::attribute protectedOnly get
::attribute transmit get
::attribute transformRequired get
::method maximumInboundPercent
  expose perContextCapPercent maxParallelContexts aggregateCapPercent
  return min(aggregateCapPercent,perContextCapPercent*maxParallelContexts)
::method value
  use strict arg decision,key,default
  if decision==.nil then return default
  if \decision~hasIndex(key) then return default
  return decision[key]
::method whole
  use strict arg decision,key,default
  v=self~value(decision,key,default)
  if datatype(v,'W')=0 then raise syntax 88.900 array('operational capacity must be integer',key)
  return v+0

::class MemoryXtpTransferSlice public
::method init
  expose offer firstByte endByte operationalClass perContextCapPercent
  use strict arg offerArg,firstArg,endArg,classArg,capArg
  if firstArg>=endArg then raise syntax 88.900 array('empty transfer slice')
  offer=offerArg; firstByte=firstArg; endByte=endArg
  operationalClass=classArg; perContextCapPercent=capArg
::attribute offer get
::attribute firstByte get
::attribute endByte get
::attribute operationalClass get
::attribute perContextCapPercent get
::method length
  expose firstByte endByte
  return endByte-firstByte

::class MemoryXtpTransferPlan public
::method init
  expose request policy slices
  use strict arg requestArg,policyArg,slicesArg
  request=requestArg; policy=policyArg; slices=slicesArg
::attribute request get
::attribute policy get
::attribute slices get
::method totalBytes
  expose slices
  n=0; do s over slices; n+=s~length; end
  return n
::method effectiveInboundPercent
  expose policy slices
  return min(policy~aggregateCapPercent,policy~perContextCapPercent*slices~items)

::class MemoryXtpTransferPlanner public
/* This is only a candidate plan. A receiver must revalidate provider epoch,
 * block identity/generation and permissions before opening EACH context and
 * again before consuming result bytes. XTP CNTL is not memory ownership proof. */
::method plan
  use strict arg request,offers,policy,authoritativeRegistry
  if request==.nil | offers==.nil | policy==.nil | authoritativeRegistry==.nil then raise syntax 88.900 array('missing Memory plan inputs')
  if \offers~isA(.Array) then raise syntax 88.900 array('Memory offers must be an Array')
  if authoritativeRegistry~fabricId<>request~fabricId then raise syntax 88.900 array('fabric authority mismatch')
  if \policy~transmit | policy~transformRequired then raise syntax 88.900 array('memory class not admitted as unmodified transfer')
  eligible=.array~new; peers=.directory~new
  do offer over offers
    if offer~fabricId=request~fabricId & offer~blockId=request~blockId & offer~blockGeneration=request~blockGeneration then do
      if self~offerCurrent(offer,authoritativeRegistry) then do
        if offer~firstByte<=request~firstByte & offer~endByte>=request~endByte then do
          if peers[offer~peerId]==.nil then do
            eligible~append(offer); peers[offer~peerId]=.true
          end
        end
      end
    end
  end
  if eligible~items=0 then raise syntax 88.900 array('no full-window current resident source evidence')
  count=min(eligible~items,policy~maxParallelContexts,request~pageCount)
  totalPages=request~pageCount
  base=totalPages%count; extra=totalPages//count
  slices=.array~new; cursor=request~firstByte
  do i=1 to count
    pages=base
    if i<=extra then pages+=1
    stop=cursor+pages*request~pageBytes
    slices~append(.MemoryXtpTransferSlice~new(eligible[i],cursor,stop,policy~className,policy~perContextCapPercent))
    cursor=stop
  end
  return .MemoryXtpTransferPlan~new(request,policy,slices)
::method offerCurrent
  use strict arg offer,registry
  p=registry~provider(offer~providerId)
  if p==.nil then return .false
  if p~membershipEpoch<>offer~ownerEpoch | p~providerGeneration<>offer~providerGeneration then return .false
  if p~providerState='OFFLINE' then return .false
  if p~providerState<>'ACTIVE' & p~providerState<>'DRAINING' then return .false
  return .true
::method revalidate
  use strict arg slice,registry
  /* Source must additionally prove block-generation authority at service ingress. */
  return self~offerCurrent(slice~offer,registry)

::class MemoryXtpServicePolicy public
::method init
  expose registry planner
  use strict arg serviceRegistry,operationalPlanner
  registry=serviceRegistry; planner=operationalPlanner
::method forService
  expose registry planner
  use strict arg serviceName,operatingState
  descriptor=registry~resolve(serviceName)
  if descriptor==.nil then raise syntax 88.900 array('unknown or disabled Memory service',serviceName)
  /* Service registration is authoritative for class; never use an incoming claim. */
  d=planner~decide(descriptor~operationalClass,operatingState)
  return .MemoryXtpTransferPolicy~new(descriptor~operationalClass,operatingState,d)

/* Explicit discovery seam: XTP MULTI with service-addressed FIRST is desired,
 * but current named-service XTP API and multicast binding remain distinct.
 * An implementation MUST refuse multicast if admission cannot be applied. */
::class MemoryXtpDiscoveryPort public
::method discover abstract

/* Additive unicast named-service bridge into the existing XTP manager.
 * The caller supplies a protocol-owned encoded control payload; this class
 * deliberately does not invent a memory page serialization or a new socket.
 * The XTP manager derives the operational class from local registration. */
::class MemoryXtpNamedControl public
::method init
  expose namedManager
  use strict arg xtpNamedServiceManager
  namedManager=xtpNamedServiceManager
::method send
  expose namedManager
  use strict arg canonicalService,payload
  socket=namedManager~sender(canonicalService)
  rc=socket~send(payload)
  socket~close
  return rc
