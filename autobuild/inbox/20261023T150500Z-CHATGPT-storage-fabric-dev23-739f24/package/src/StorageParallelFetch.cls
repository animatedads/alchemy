/* ooRexx Storage Fabric v0.1-dev23
 * Transport-neutral multi-source ranged acquisition planning.
 *
 * Storage Fabric decides WHO supplies WHICH byte ranges.  It never carries
 * physical IP addressing.  Named-service authority supplies the registered
 * operational class; the degradation planner supplies class capacity limits;
 * the selected transport enforces its own wire mechanics.
 */

::class StorageParallelFetchBuild public
::constant VERSION "0.1-dev23"
::constant API "storage.fabric.parallel-fetch/0.1"

::class StorageRangeSearchRequest public
::attribute serviceName get
::attribute objectId get
::attribute startOffset get
::attribute endOffset get
::attribute length get
::method init
  expose serviceName objectId startOffset endOffset length
  use strict arg serviceArg, objectArg, startArg, endArg
  serviceName=serviceArg~string~strip
  objectId=objectArg~string~strip
  if datatype(startArg,'W')=0 | datatype(endArg,'W')=0 then raise syntax 88.900 array('storage region offsets must be whole numbers')
  startOffset=startArg; endOffset=endArg
  if serviceName='' | objectId='' then raise syntax 88.900 array('service and object are mandatory')
  if startOffset<0 | endOffset<=startOffset then raise syntax 88.900 array('invalid requested storage region',startOffset,endOffset)
  length=endOffset-startOffset

::class StorageRangeOffer public
::attribute peerId get
::attribute objectId get
::attribute startOffset get
::attribute endOffset get
::attribute verified get
::attribute evidenceRef get
::attribute length get
::method init
  expose peerId objectId startOffset endOffset verified evidenceRef length
  use strict arg peerArg, objectArg, startArg, endArg, verifiedArg=.true, evidenceArg=''
  peerId=peerArg~string~strip; objectId=objectArg~string~strip
  if datatype(startArg,'W')=0 | datatype(endArg,'W')=0 then raise syntax 88.900 array('offered region offsets must be whole numbers')
  startOffset=startArg; endOffset=endArg
  verified=(verifiedArg==.true); evidenceRef=evidenceArg~string
  if peerId='' | objectId='' then raise syntax 88.900 array('offer peer and object are mandatory')
  if self~looksLikeIp(peerId) then raise syntax 88.900 array('Storage offers use logical peer IDs, not IP addresses',peerId)
  if startOffset<0 | endOffset<=startOffset then raise syntax 88.900 array('invalid offered storage region',startOffset,endOffset)
  length=endOffset-startOffset
::method covers
  expose startOffset endOffset
  use strict arg startArg,endArg
  if datatype(startArg,'W')=0 | datatype(endArg,'W')=0 then return .false
  if startOffset>startArg then return .false
  if endOffset<endArg then return .false
  return .true
::method looksLikeIp
  use strict arg value
  if value~countstr(':')>1 | pos('[',value)>0 | pos(']',value)>0 then return .true
  if value~countstr('.')=3 then do
    rest=value; numeric=.true
    do 4
      parse var rest p '.' rest
      if p='' | datatype(p,'W')=0 | p<0 | p>255 then numeric=.false
    end
    if numeric then return .true
  end
  return .false

::class StorageFetchPolicy public
::attribute className get
::attribute state get
::attribute disposition get
::attribute ratePercent get
::attribute perContextCapPercent get
::attribute maxParallelContexts get
::attribute aggregateCapPercent get
::attribute fallbackPolicy get
::attribute protectedOnly get
::attribute transmit get
::attribute transformRequired get
::method init
  expose className state disposition ratePercent perContextCapPercent maxParallelContexts aggregateCapPercent fallbackPolicy protectedOnly transmit transformRequired
  use strict arg classArg,stateArg,decision
  className=classArg~string~strip; state=stateArg~string~strip~lower
  disposition=self~value(decision,'ACTION','allow')~lower
  ratePercent=self~whole(decision,'RATE_PERCENT',100)
  perContextCapPercent=self~whole(decision,'PER_CONTEXT_CAP_PERCENT',100)
  maxParallelContexts=self~whole(decision,'MAX_PARALLEL_CONTEXTS',1)
  aggregateCapPercent=self~whole(decision,'AGGREGATE_CAP_PERCENT',100)
  fallbackPolicy=self~value(decision,'FALLBACK','allow')~lower
  protectedOnly=(self~whole(decision,'PROTECTED_ONLY',0)=1)
  transmit=(self~whole(decision,'TRANSMIT',1)=1)
  transformRequired=(self~whole(decision,'TRANSFORM',0)=1)
  if ratePercent<0 | ratePercent>100 then raise syntax 88.900 array('RATE_PERCENT outside 0..100')
  if perContextCapPercent<1 | perContextCapPercent>100 then raise syntax 88.900 array('PER_CONTEXT_CAP_PERCENT outside 1..100')
  if maxParallelContexts<1 then raise syntax 88.900 array('MAX_PARALLEL_CONTEXTS must be positive')
  if aggregateCapPercent<1 | aggregateCapPercent>100 then raise syntax 88.900 array('AGGREGATE_CAP_PERCENT outside 1..100')
::method effectivePerContextPercent
  expose disposition ratePercent perContextCapPercent
  cap=perContextCapPercent
  if disposition='throttle' then do
    if ratePercent<cap then cap=ratePercent
  end
  return cap
::method maximumAggregatePercent
  expose maxParallelContexts aggregateCapPercent
  possible=self~effectivePerContextPercent*maxParallelContexts
  return min(possible,aggregateCapPercent)
::method value
  use strict arg d,k,default
  if d==.nil then return default
  if \d~hasIndex(k) then return default
  return d[k]
::method whole
  use strict arg d,k,default
  v=self~value(d,k,default)
  if datatype(v,'W')=0 then raise syntax 88.900 array('planner value must be an integer',k,v)
  return v

::class StorageFetchSlice public
::attribute peerId get
::attribute startOffset get
::attribute endOffset get
::attribute length get
::attribute perContextCapPercent get
::attribute operationalClass get
::method init
  expose peerId startOffset endOffset length perContextCapPercent operationalClass
  use strict arg peerArg,startArg,endArg,capArg,classArg
  if datatype(startArg,'W')=0 | datatype(endArg,'W')=0 | datatype(capArg,'W')=0 then raise syntax 88.900 array('fetch slice numeric fields must be whole numbers')
  peerId=peerArg~string; startOffset=startArg; endOffset=endArg
  perContextCapPercent=capArg; operationalClass=classArg~string
  if endOffset<=startOffset then raise syntax 88.900 array('empty fetch slice')
  length=endOffset-startOffset

::class StorageFetchPlan public
::attribute request get
::attribute policy get
::attribute slices get
::attribute effectiveInboundPercent get
::attribute requestedSources get
::method init
  expose request policy slices effectiveInboundPercent requestedSources
  use strict arg requestArg,policyArg,slicesArg
  request=requestArg; policy=policyArg; slices=slicesArg
  requestedSources=slices~items
  effectiveInboundPercent=min(policy~aggregateCapPercent,policy~effectivePerContextPercent*requestedSources)
::method totalBytes
  expose slices
  n=0; do s over slices; n+=s~length; end
  return n

::class StorageMultiSourcePlanner public
/* Build a contiguous acquisition plan. Full-replica offers are split evenly;
 * partial offers are consumed greedily by farthest coverage.  A peer is used
 * at most once, so maxParallelContexts is an actual context/fan-in cap. */
::method plan
  use strict arg request,offers,policy
  if request==.nil | offers==.nil | policy==.nil then raise syntax 88.900 array('request, offers and policy are mandatory')
  if \offers~isA(.Array) then raise syntax 88.900 array('offers must be an Array')
  if \policy~transmit then raise syntax 88.900 array('operational class is not admitted',policy~className,policy~state,policy~disposition)
  if policy~transformRequired then raise syntax 88.900 array('upstream transformation required before storage acquisition',policy~className)
  eligible=.array~new
  do o over offers
    if o~objectId=request~objectId then do
      if o~verified then do
        if o~endOffset>request~startOffset then do
          if o~startOffset<request~endOffset then eligible~append(o)
        end
      end
    end
  end
  if eligible~items=0 then raise syntax 88.900 array('no verified source offers for requested region',request~objectId)

  maxSources=min(policy~maxParallelContexts,eligible~items)
  full=.array~new
  do o over eligible
    if o~covers(request~startOffset,request~endOffset) then full~append(o)
  end
  if full~items>=maxSources then return self~splitFullReplicas(request,full,policy,maxSources)
  return self~greedyCoverage(request,eligible,policy,maxSources)

::method splitFullReplicas
  use strict arg request,offers,policy,count
  slices=.array~new
  do i=1 to count
    slices~append(self~fullReplicaSlice(request,offers[i],policy,i,count))
  end
  return .StorageFetchPlan~new(request,policy,slices)

::method fullReplicaSlice
  use strict arg request,offer,policy,index,count
  total=request~length
  base=total%count; remainder=total//count
  before=index-1
  extraBefore=min(before,remainder)
  start=request~startOffset+(before*base)+extraBefore
  bytes=base
  if index<=remainder then bytes+=1
  stop=start+bytes
  return .StorageFetchSlice~new(offer~peerId,start,stop,policy~effectivePerContextPercent,policy~className)

::method greedyCoverage
  use strict arg request,offers,policy,maxSources
  slices=.array~new; used=.directory~new; cursor=request~startOffset
  do while cursor<request~endOffset
    if slices~items>=maxSources then raise syntax 88.900 array('requested region needs more source contexts than policy permits',maxSources)
    best=.nil; bestEnd=cursor
    do o over offers
      if used[o~peerId]==.nil then do
        if o~startOffset<=cursor then do
          if o~endOffset>bestEnd then do
            best=o; bestEnd=o~endOffset
          end
        end
      end
    end
    if best==.nil then raise syntax 88.900 array('source offers leave an uncovered region',cursor,request~endOffset)
    stop=min(bestEnd,request~endOffset)
    slices~append(.StorageFetchSlice~new(best~peerId,cursor,stop,policy~effectivePerContextPercent,policy~className))
    used[best~peerId]=.true; cursor=stop
  end
  return .StorageFetchPlan~new(request,policy,slices)

::class StorageOperationalFetchControl public
::method init
  expose serviceRegistry operationalPlanner
  use strict arg serviceRegistryArg,plannerArg
  serviceRegistry=serviceRegistryArg; operationalPlanner=plannerArg
  if serviceRegistry==.nil | operationalPlanner==.nil then raise syntax 88.900 array('service registry and operational planner are mandatory')
::method policyForService
  expose serviceRegistry operationalPlanner
  use strict arg serviceName,state
  d=serviceRegistry~resolve(serviceName)
  if d==.nil then raise syntax 88.900 array('named storage service is not registered/enabled',serviceName)
  decision=operationalPlanner~decide(d~operationalClass,state)
  return .StorageFetchPolicy~new(d~operationalClass,state,decision)
::method plan
  use strict arg serviceName,objectId,startOffset,endOffset,state,offers
  request=.StorageRangeSearchRequest~new(serviceName,objectId,startOffset,endOffset)
  policy=self~policyForService(serviceName,state)
  return .StorageMultiSourcePlanner~new~plan(request,offers,policy)

/* Implementations may use XTP MULTI, NORM, XMPP or another discovery carrier.
 * Storage only requires a collection of logical-peer range offers back. */
::class StorageRangeDiscoveryPort public
::method search abstract

/* dev23: bind a completed multi-source plan to a transport-neutral capacity
 * governor. The governor owns live admission/rate state; Storage owns which
 * logical peer supplies which byte range. */
::class StorageFetchAdmission public
::method init
  expose plan domain tickets governor
  use strict arg fetchPlan, capacityDomain, ticketArray, capacityGovernor
  plan=fetchPlan; domain=capacityDomain; tickets=ticketArray; governor=capacityGovernor
::attribute plan get
::attribute domain get
::attribute tickets get
::method release
  expose tickets governor
  ok=.true
  do t over tickets
    if \governor~release(t['ID']) then ok=.false
  end
  return ok
::method reconcile
  expose plan domain governor tickets
  use strict arg operatingState
  tickets=governor~reconcile(plan~policy~className,operatingState,domain)
  return tickets
::method refreshDomain
  expose domain governor tickets
  if \governor~refreshDomain(domain) then return .false
  refreshed=.array~new
  do t over tickets
    refreshed~append(governor~ticket(t['ID']))
  end
  tickets=refreshed
  return .true
::method sender
  expose tickets governor
  use strict arg sliceIndex, transportSocket
  if \datatype(sliceIndex,'W') | sliceIndex<1 | sliceIndex>tickets~items then raise syntax 88.900 array('invalid storage slice index',sliceIndex)
  return .StorageCapacitySender~new(transportSocket,governor,tickets[sliceIndex]['ID'])

::class StorageCapacityAdmission public
::method init
  expose governor
  use strict arg capacityGovernor
  if capacityGovernor==.nil then raise syntax 88.900 array('capacity governor is mandatory')
  governor=capacityGovernor
::method admit
  expose governor
  use strict arg plan, capacityDomain
  if plan==.nil then raise syntax 88.900 array('fetch plan is mandatory')
  domain=capacityDomain~string~strip
  if domain='' then raise syntax 88.900 array('capacity domain is mandatory')
  tickets=.array~new
  do slice over plan~slices
    t=governor~acquire(plan~policy~className,plan~policy~state,domain)
    if t==.nil then do
      do prior over tickets; ignored=governor~release(prior['ID']); end
      raise syntax 88.900 array('capacity admission refused storage slice',slice~peerId,plan~policy~className,domain)
    end
    tickets~append(t)
  end
  return .StorageFetchAdmission~new(plan,domain,tickets,governor)

/* Transport-neutral ticket adapter. A transport must explicitly expose a
 * CAPACITYRATE method to accept the ticket's byte-rate ceiling. Otherwise a
 * limited ticket fails closed rather than pretending the cap is enforced. */
::class StorageCapacitySender public
::method init
  expose socket governor ticketId closed
  use strict arg transportSocket, capacityGovernor, capacityTicketId
  socket=transportSocket; governor=capacityGovernor; ticketId=capacityTicketId; closed=.false
::method send
  expose socket governor ticketId closed
  use strict arg bytes
  if closed then return -1
  t=governor~ticket(ticketId)
  if t==.nil then return -2
  if t['ADMITTED']<>1 then return -2
  rate=t['BYTES_PER_SEC']
  if rate==.nil | \datatype(rate,'W') | rate<1 then return -2
  if \socket~hasMethod('CAPACITYRATE') then return -3
  ignored=socket~capacityRate(rate)
  return socket~send(bytes)
::method close
  expose socket closed
  if closed then return 0
  closed=.true
  return socket~close
