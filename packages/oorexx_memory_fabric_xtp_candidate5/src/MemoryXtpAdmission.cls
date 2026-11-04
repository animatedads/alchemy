/* Admission and capacity-governed named XTP control for Memory Fabric.
 * This is a transport adapter, NOT a remote-memory read/write protocol.
 * Caller supplies authenticated Memory Fabric authority for replicas.
 * XTP's wire ACK is not a memory lease or a block-commit receipt.
 */

::class MemoryXtpAuthority public
::method init
  expose registry replicaVerifier
  use strict arg authoritativeRegistry, trustedReplicaVerifier=.nil
  registry=authoritativeRegistry; replicaVerifier=trustedReplicaVerifier
::method current
  expose registry replicaVerifier
  use strict arg request,slice
  offer=slice~offer
  if registry~fabricId<>request~fabricId then return .false
  if offer~fabricId<>request~fabricId | offer~blockId<>request~blockId | offer~blockGeneration<>request~blockGeneration then return .false
  if \offer~covers(slice~firstByte,slice~endByte) then return .false
  if slice~firstByte<request~firstByte | slice~endByte>request~endByte then return .false
  if slice~firstByte//request~pageBytes<>0 | slice~endByte//request~pageBytes<>0 then return .false
  checker=.MemoryXtpTransferPlanner~new
  if \checker~offerCurrent(offer,registry) then return .false
  block=registry~resolveBlock(request~blockId,request~blockGeneration)
  if block==.nil then return .false
  if block~blockId<>request~blockId | block~generation<>request~blockGeneration then return .false
  if slice~endByte>block~length then return .false
  if block~providerId=offer~providerId then return block~ownerEpoch=offer~ownerEpoch
  /* Replica claims are NOT proven by an evidence string alone. An
   * independent authoritative verifier is mandatory for nonowner peers. */
  if replicaVerifier==.nil then return .false
  if \replicaVerifier~hasMethod('VERIFIES') then return .false
  return replicaVerifier~verifies(offer,request,slice~firstByte,slice~endByte)==.true

::class MemoryXtpCapacityAdmission public
::method init
  expose authority governor
  use strict arg blockAuthority, operationalCapacityGovernor
  if blockAuthority==.nil | operationalCapacityGovernor==.nil then raise syntax 88.900 array('Memory XTP authority and governor required')
  authority=blockAuthority; governor=operationalCapacityGovernor
::method admit
  expose authority governor
  use strict arg plan, capacityDomain
  domain=capacityDomain~string~strip
  if plan==.nil | domain='' then raise syntax 88.900 array('Memory XTP plan/capacity domain required')
  if \plan~policy~transmit | plan~policy~transformRequired then raise syntax 88.900 array('Memory XTP transfer denied by policy')
  if plan~slices~items<1 | plan~slices~items>plan~policy~maxParallelContexts then raise syntax 88.900 array('Memory XTP fanin outside policy')
  if plan~slices~items*plan~policy~perContextCapPercent>plan~policy~aggregateCapPercent then raise syntax 88.900 array('Memory XTP aggregate exceeded')
  cursor=plan~request~firstByte
  do slice over plan~slices
    if slice~firstByte<>cursor then raise syntax 88.900 array('Memory XTP noncontiguous or overlapping slices')
    if slice~operationalClass<>plan~policy~className then raise syntax 88.900 array('Memory XTP forged class in slice')
    if \authority~current(plan~request,slice) then raise syntax 88.900 array('Memory XTP unverified resident block evidence',slice~offer~providerId)
    cursor=slice~endByte
  end
  if cursor<>plan~request~endByte then raise syntax 88.900 array('Memory XTP incomplete window')
  tickets=.array~new
  do slice over plan~slices
    ticket=governor~acquire(plan~policy~className,plan~policy~state,domain)
    if ticket==.nil then do
      do prior over tickets
        ignored=governor~release(prior['ID'])
      end
      raise syntax 88.900 array('Memory XTP capacity refused',domain)
    end
    tickets~append(ticket)
  end
  return .MemoryXtpAdmission~new(plan,domain,tickets,governor,authority)

::class MemoryXtpAdmission public
::method init
  expose plan domain tickets governor authority released
  use strict arg planArg, domainArg, ticketsArg, governorArg, authorityArg
  plan=planArg; domain=domainArg; tickets=ticketsArg; governor=governorArg; authority=authorityArg; released=.false
::attribute domain get
::attribute plan get
::attribute tickets get
::method release
  expose released tickets governor
  if released then return .true
  released=.true
  ok=.true
  do t over tickets
    if \governor~release(t['ID']) then ok=.false
  end
  return ok
::method refreshDomain
  expose released governor domain
  if released then return .false
  return governor~refreshDomain(domain)
::method reconcile
  expose released governor plan domain
  use strict arg operatingState
  if released then return .array~new
  return governor~reconcile(plan~policy~className,operatingState,domain)
::method sendControl
  expose released tickets plan governor authority
  use strict arg index, namedManager, serviceName, payload
  if released then return -1
  if \datatype(index,'W') | index<1 | index>tickets~items then return -2
  slice=plan~slices[index]
  if \authority~current(plan~request,slice) then return -3
  if \payload~isA(.String) then return -4
  if length(payload)>65536 then return -4
  /* Class and route peer must derive from registry, not a caller assertion. */
  d=namedManager~descriptor(serviceName)
  if d~routePeer<>slice~offer~peerId then return -5
  if d~operationalClass<>plan~policy~className then return -5
  t=governor~ticket(tickets[index]['ID'])
  if t==.nil then return -6
  if t['ADMITTED']<>1 then return -6
  rate=t['BYTES_PER_SEC']
  if rate==.nil | \datatype(rate,'W') | rate<1 then return -6
  socket=namedManager~sender(serviceName)
  /* Do not silently remove pacing when a backend lacks capacityRate. */
  if \socket~hasMethod('CAPACITYRATE') then do
    ignored=socket~close
    return -7
  end
  ignored=socket~capacityRate(rate)
  /* Recheck immediately before send; XTP ACK does not confer block authority. */
  if \authority~current(plan~request,slice) then do
    ignored=socket~close
    return -3
  end
  rc=socket~send(payload)
  ignored=socket~close
  return rc
::requires 'MemoryXtpTransferPlanning.cls'
