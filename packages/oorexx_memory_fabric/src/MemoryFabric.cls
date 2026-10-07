/* MemoryFabric.cls
 * ooRexx Memory Fabric v0.1-dev6
 *
 * Service contract: memory.fabric/0.1
 *
 * Authority split:
 *   - Managed Unit (MU) is the discovery/deployment authority for the service.
 *   - A provider may be the MU itself or an MI hosted by the MU.
 *   - Memory Fabric owns provider/block identity, residency and generation.
 *   - Job-to-Node remains placement/admission authority for execution.
 *   - RTO/RTO2 may reconstruct a provider MI at a state point.
 *
 * This layer deliberately does not pretend remote RAM is ordinary shared memory.
 * Callers resolve block ownership and move/dispatch execution toward resident data.
 */

::class MemoryFabricBuild public
::constant VERSION "0.1-dev6"
::constant API "memory.fabric/0.1"

::class MemoryFabricProviderKind public
::constant MANAGED_UNIT "MU"
::constant MANAGED_INSTANCE "MI"

::class MemoryFabricProviderState public
::constant ACTIVE "ACTIVE"
::constant SPARE "SPARE"
::constant DRAINING "DRAINING"
::constant OFFLINE "OFFLINE"

::class MemoryFabricAllocationState public
::constant ACCEPTING "ACCEPTING"
::constant RESERVED "RESERVED"
::constant DRAINING "DRAINING"
::constant CLOSED "CLOSED"

::class MemoryFabricRecoveryClass public
::constant VOLATILE "VOLATILE"
::constant RECONSTRUCTABLE "RECONSTRUCTABLE"
::constant REPLICATED "REPLICATED"
::constant CHECKPOINTED "CHECKPOINTED"

::class MemoryFabricLocality public
::constant SAME_PROVIDER 0
::constant SAME_MI 5
::constant SAME_MU 10
::constant SAME_MACHINE 20
::constant SAME_RACK 30
::constant SAME_SITE 40
::constant SAME_REGION 50
::constant REMOTE 100

::class MemoryFabricProvider public

::method init
  expose providerId kind muId miId siteId machineId endpoint capacityBytes committedBytes providerState allocationState membershipEpoch providerGeneration bootId
  use strict arg providerId, kind, muId, miId="", siteId="", machineId="", endpoint="", capacityBytes=0, committedBytes=0, providerState="ACTIVE", allocationState="ACCEPTING", membershipEpoch=1, providerGeneration=1, bootId=""
  numeric digits 20
  providerId=providerId~string~strip
  kind=kind~string~strip~upper
  muId=muId~string~strip
  miId=miId~string~strip
  siteId=siteId~string~strip
  machineId=machineId~string~strip
  endpoint=endpoint~string~strip
  capacityBytes=capacityBytes+0
  committedBytes=committedBytes+0
  providerState=providerState~string~strip~upper
  allocationState=allocationState~string~strip~upper
  membershipEpoch=membershipEpoch+0
  providerGeneration=providerGeneration+0
  bootId=bootId~string~strip

  if providerId="" then raise syntax 88.900 array("providerId must not be empty")
  if muId="" then raise syntax 88.900 array("muId must not be empty")
  if kind<>.MemoryFabricProviderKind~MANAGED_UNIT & kind<>.MemoryFabricProviderKind~MANAGED_INSTANCE then
    raise syntax 88.900 array("provider kind must be MU or MI")
  if kind=.MemoryFabricProviderKind~MANAGED_INSTANCE & miId="" then
    raise syntax 88.900 array("MI provider requires miId")
  if capacityBytes<0 | committedBytes<0 | committedBytes>capacityBytes then
    raise syntax 88.900 array("invalid provider capacity")
  if membershipEpoch<1 | providerGeneration<1 then
    raise syntax 88.900 array("epochs/generations must be positive")

::attribute providerId get
::attribute kind get
::attribute muId get
::attribute miId get
::attribute siteId get
::attribute machineId get
::attribute endpoint get
::attribute capacityBytes get
::attribute committedBytes get
::attribute providerState get
::attribute allocationState get
::attribute membershipEpoch get
::attribute providerGeneration get
::attribute bootId get

::method availableBytes
  expose capacityBytes committedBytes
  numeric digits 20
  return capacityBytes-committedBytes

::method acceptsGeneralAllocation
  expose providerState allocationState
  return providerState=.MemoryFabricProviderState~ACTIVE & allocationState=.MemoryFabricAllocationState~ACCEPTING

::method eligibleAsSpare
  expose providerState allocationState
  return providerState=.MemoryFabricProviderState~SPARE & allocationState<>.MemoryFabricAllocationState~CLOSED

::method withState
  expose providerId kind muId miId siteId machineId endpoint capacityBytes committedBytes membershipEpoch providerGeneration bootId
  use strict arg newProviderState, newAllocationState
  numeric digits 20
  return .MemoryFabricProvider~new(providerId,kind,muId,miId,siteId,machineId,endpoint,capacityBytes,committedBytes,newProviderState,newAllocationState,membershipEpoch,providerGeneration,bootId)

::method withCommitted
  expose providerId kind muId miId siteId machineId endpoint capacityBytes providerState allocationState membershipEpoch providerGeneration bootId
  use strict arg newCommitted
  numeric digits 20
  return .MemoryFabricProvider~new(providerId,kind,muId,miId,siteId,machineId,endpoint,capacityBytes,newCommitted,providerState,allocationState,membershipEpoch,providerGeneration,bootId)

::method withLifecycle
  expose providerId kind muId miId siteId machineId endpoint capacityBytes committedBytes membershipEpoch providerGeneration bootId
  use strict arg newProviderState, newAllocationState, advanceGeneration=.true
  numeric digits 20
  g=providerGeneration
  if advanceGeneration then g+=1
  return .MemoryFabricProvider~new(providerId,kind,muId,miId,siteId,machineId,endpoint,capacityBytes,committedBytes,newProviderState,newAllocationState,membershipEpoch,g,bootId)

::method reincarnate
  expose providerId kind muId miId siteId machineId endpoint capacityBytes committedBytes membershipEpoch providerGeneration
  use strict arg newBootId, newEndpoint=""
  numeric digits 20
  if newEndpoint="" then newEndpoint=endpoint
  return .MemoryFabricProvider~new(providerId,kind,muId,miId,siteId,machineId,newEndpoint,capacityBytes,committedBytes,.MemoryFabricProviderState~ACTIVE,.MemoryFabricAllocationState~ACCEPTING,membershipEpoch+1,providerGeneration+1,newBootId)


::class MemoryFabricBlockRef public

::method init
  expose blockId generation providerId offset length recoveryClass recoveryRef ownerEpoch
  use strict arg blockId, generation, providerId, offset, length, recoveryClass="VOLATILE", recoveryRef="", ownerEpoch=1
  numeric digits 20
  blockId=blockId~string~strip
  generation=generation+0
  providerId=providerId~string~strip
  offset=offset+0
  length=length+0
  recoveryClass=recoveryClass~string~strip~upper
  recoveryRef=recoveryRef~string
  ownerEpoch=ownerEpoch+0
  if blockId="" | providerId="" then raise syntax 88.900 array("blockId/providerId are mandatory")
  if generation<1 | ownerEpoch<1 | offset<0 | length<0 then raise syntax 88.900 array("invalid block address")

::attribute blockId get
::attribute generation get
::attribute providerId get
::attribute offset get
::attribute length get
::attribute recoveryClass get
::attribute recoveryRef get
::attribute ownerEpoch get

::method canonical
  expose blockId generation providerId offset length recoveryClass recoveryRef ownerEpoch
  return "block="||blockId||";generation="||generation||";provider="||providerId||";offset="||offset||";length="||length||";recovery="||recoveryClass||";recoveryRef="||recoveryRef||";ownerEpoch="||ownerEpoch


::class MemoryFabricServiceBinding public

::method init
  expose fabricId muId providerId serviceApi endpoint bindingGeneration
  use strict arg fabricId, muId, providerId, serviceApi="memory.fabric/0.1", endpoint="", bindingGeneration=1
  numeric digits 20
  fabricId=fabricId~string~strip
  muId=muId~string~strip
  providerId=providerId~string~strip
  serviceApi=serviceApi~string~strip
  endpoint=endpoint~string~strip
  bindingGeneration=bindingGeneration+0
  if fabricId="" | muId="" | providerId="" then raise syntax 88.900 array("fabricId/muId/providerId are mandatory")

::attribute fabricId get
::attribute muId get
::attribute providerId get
::attribute serviceApi get
::attribute endpoint get
::attribute bindingGeneration get


::class MemoryFabricRegistry public

::method init
  expose fabricId providers providerById bindings bindingByMu blocks blockById
  use strict arg fabricId
  numeric digits 20
  fabricId=fabricId~string~strip
  if fabricId="" then raise syntax 88.900 array("fabricId must not be empty")
  providers=.array~new
  providerById=.directory~new
  bindings=.array~new
  bindingByMu=.directory~new
  blocks=.array~new
  blockById=.directory~new

::attribute fabricId get

::method registerProvider
  expose providers providerById
  use strict arg provider
  numeric digits 20
  old=providerById[provider~providerId]
  if old<>.nil then do
    /* Same provider may advance, but an older epoch/generation must not resurrect. */
    if provider~membershipEpoch<old~membershipEpoch then return .false
    if provider~membershipEpoch=old~membershipEpoch & provider~providerGeneration<old~providerGeneration then return .false
    providerById[provider~providerId]=provider
    do i=1 to providers~items
      if providers[i]~providerId=provider~providerId then do
        providers[i]=provider
        return .true
      end
    end
  end
  providerById[provider~providerId]=provider
  providers~append(provider)
  return .true

::method provider
  expose providerById
  use strict arg providerId
  numeric digits 20
  return providerById[providerId~string]

::method bindMU
  expose bindings bindingByMu providerById fabricId
  use strict arg muId, providerId, endpoint="", bindingGeneration=1
  numeric digits 20
  p=providerById[providerId~string]
  if p=.nil then return .nil
  if p~muId<>muId~string then return .nil
  old=bindingByMu[muId~string]
  if old<>.nil then
    if bindingGeneration+0<old~bindingGeneration then return .nil
  b=.MemoryFabricServiceBinding~new(fabricId,muId,providerId,.MemoryFabricBuild~API,endpoint,bindingGeneration)
  bindingByMu[muId~string]=b
  found=.false
  do i=1 to bindings~items
    if bindings[i]~muId=muId~string then do
      bindings[i]=b
      found=.true
      leave
    end
  end
  if \found then bindings~append(b)
  return b

::method bindingForMU
  expose bindingByMu
  use strict arg muId
  numeric digits 20
  return bindingByMu[muId~string]

::method discoverForMU
  expose bindingByMu providerById
  use strict arg muId
  numeric digits 20
  b=bindingByMu[muId~string]
  if b=.nil then return .nil
  p=providerById[b~providerId]
  if p=.nil then return .nil
  if p~providerState=.MemoryFabricProviderState~OFFLINE then return .nil
  d=.directory~new
  d["fabric_id"]=b~fabricId
  d["service_api"]=b~serviceApi
  d["provider_id"]=p~providerId
  d["provider_kind"]=p~kind
  d["provider_mu"]=p~muId
  d["provider_mi"]=p~miId
  d["endpoint"]=b~endpoint
  d["binding_generation"]=b~bindingGeneration
  d["provider_generation"]=p~providerGeneration
  d["membership_epoch"]=p~membershipEpoch
  return d

::method transitionProvider
  expose providerById
  use strict arg providerId, expectedMembershipEpoch, newProviderState, newAllocationState
  numeric digits 20
  p=providerById[providerId~string]
  if p=.nil then return .nil
  if p~membershipEpoch<>expectedMembershipEpoch+0 then return .nil
  newProviderState=newProviderState~string~upper
  newAllocationState=newAllocationState~string~upper
  /* DRAINING keeps existing blocks resolvable but prevents new allocation.
   * OFFLINE closes the provider.  A replacement incarnation must use a new
   * membership epoch (reincarnateProvider), which fences old block handles. */
  if newProviderState=.MemoryFabricProviderState~DRAINING then newAllocationState=.MemoryFabricAllocationState~DRAINING
  if newProviderState=.MemoryFabricProviderState~OFFLINE then newAllocationState=.MemoryFabricAllocationState~CLOSED
  if newProviderState=.MemoryFabricProviderState~SPARE & newAllocationState=.MemoryFabricAllocationState~ACCEPTING then newAllocationState=.MemoryFabricAllocationState~RESERVED
  updated=p~withLifecycle(newProviderState,newAllocationState,.true)
  if \self~registerProvider(updated) then return .nil
  return updated

::method reincarnateProvider
  expose providerById
  use strict arg providerId, expectedMembershipEpoch, newBootId, newEndpoint=""
  numeric digits 20
  p=providerById[providerId~string]
  if p=.nil then return .nil
  if p~membershipEpoch<>expectedMembershipEpoch+0 then return .nil
  if newEndpoint="" then newEndpoint=p~endpoint
  updated=p~reincarnate(newBootId,newEndpoint)
  if \self~registerProvider(updated) then return .nil
  return updated

::method lifecycleObligations
  expose blocks
  use strict arg providerId
  answer=.array~new
  do b over blocks
    if b~providerId=providerId~string then do
      d=.directory~new
      d["block_id"]=b~blockId
      d["generation"]=b~generation
      d["recovery_class"]=b~recoveryClass
      d["recovery_ref"]=b~recoveryRef
      select
        when b~recoveryClass=.MemoryFabricRecoveryClass~VOLATILE then d["action"]="DROP_ON_OFFLINE"
        when b~recoveryClass=.MemoryFabricRecoveryClass~RECONSTRUCTABLE then d["action"]="RECONSTRUCT_FROM_REFERENCE"
        when b~recoveryClass=.MemoryFabricRecoveryClass~REPLICATED then d["action"]="VERIFY_OR_PROMOTE_REPLICA"
        when b~recoveryClass=.MemoryFabricRecoveryClass~CHECKPOINTED then d["action"]="RESTORE_CHECKPOINT"
        otherwise d["action"]="UNCLASSIFIED"
      end
      answer~append(d)
    end
  end
  return answer

::method publishBlock
  expose providerById blocks blockById
  use strict arg block
  numeric digits 20
  p=providerById[block~providerId]
  if p=.nil then return .false
  if block~ownerEpoch<>p~membershipEpoch then return .false

  old=blockById[block~blockId]
  if old<>.nil then
    if block~generation<=old~generation then return .false

  blockById[block~blockId]=block
  found=.false
  do i=1 to blocks~items
    if blocks[i]~blockId=block~blockId then do
      blocks[i]=block
      found=.true
      leave
    end
  end
  if \found then blocks~append(block)
  return .true

::method block
  expose blockById
  use strict arg blockId
  numeric digits 20
  return blockById[blockId~string]

::method resolveBlock
  expose blockById providerById
  use strict arg blockId, generation
  numeric digits 20
  b=blockById[blockId~string]
  if b=.nil then return .nil
  if b~generation<>generation+0 then return .nil
  p=providerById[b~providerId]
  if p=.nil then return .nil
  if b~ownerEpoch<>p~membershipEpoch then return .nil
  if p~providerState=.MemoryFabricProviderState~OFFLINE then return .nil
  return b

::method providers
  expose providers
  answer=.array~new
  do p over providers
    answer~append(p)
  end
  return answer

::method bestProvider
  expose providers
  use strict arg requesterMuId, requesterMachineId, requesterSiteId, bytes, allowSpare=.false
  numeric digits 20
  best=.nil
  bestCost=999999
  do p over providers
    eligible=p~acceptsGeneralAllocation
    if allowSpare then eligible=eligible | p~eligibleAsSpare
    if eligible & p~availableBytes>=bytes+0 then do
      cost=self~localityCost(requesterMuId,requesterMachineId,requesterSiteId,p)
      if best=.nil | cost<bestCost then do
        best=p
        bestCost=cost
      end
    end
  end
  return best

::method localityCost
  use strict arg requesterMuId, requesterMachineId, requesterSiteId, provider
  numeric digits 20
  if provider~muId=requesterMuId~string then return .MemoryFabricLocality~SAME_MU
  if requesterMachineId<>"" & provider~machineId=requesterMachineId~string then return .MemoryFabricLocality~SAME_MACHINE
  if requesterSiteId<>"" & provider~siteId=requesterSiteId~string then return .MemoryFabricLocality~SAME_SITE
  return .MemoryFabricLocality~REMOTE


::class MemoryFabricAllocation public

::method init
  expose allocationId providerId bytes jobId recoveryClass state
  use strict arg allocationId, providerId, bytes, jobId="", recoveryClass="VOLATILE", state="RESERVED"
  numeric digits 20
  allocationId=allocationId~string~strip
  providerId=providerId~string~strip
  bytes=bytes+0
  jobId=jobId~string~strip
  recoveryClass=recoveryClass~string~strip~upper
  state=state~string~strip~upper

::attribute allocationId get
::attribute providerId get
::attribute bytes get
::attribute jobId get
::attribute recoveryClass get
::attribute state get


::class MemoryFabricAllocator public

::method init
  expose registry nextId allocations
  use strict arg registry
  numeric digits 20
  allocations=.array~new
  nextId=1

::method reserveBest
  expose registry nextId allocations
  use strict arg requesterMuId, requesterMachineId, requesterSiteId, bytes, jobId="", recoveryClass="VOLATILE", allowSpare=.false
  numeric digits 20
  p=registry~bestProvider(requesterMuId,requesterMachineId,requesterSiteId,bytes,allowSpare)
  if p=.nil then return .nil
  newCommitted=p~committedBytes+bytes
  if newCommitted>p~capacityBytes then return .nil
  updated=p~withCommitted(newCommitted)
  if \registry~registerProvider(updated) then return .nil
  id="memalloc-"||nextId
  nextId+=1
  a=.MemoryFabricAllocation~new(id,p~providerId,bytes,jobId,recoveryClass)
  allocations~append(a)
  return a

::method allocations
  expose allocations
  answer=.array~new
  do a over allocations
    answer~append(a)
  end
  return answer


/* -------------------------------------------------------------------------
 * v0.1-dev2: multi-provider logical capacity planning.
 *
 * A Memory Fabric request may be satisfied by more than one provider.  The
 * plan keeps each physical residency explicit; it does NOT turn those blocks
 * into transparent cross-machine pointers.
 * ---------------------------------------------------------------------- */

::class MemoryFabricCapacityFragment public

::method init
  expose providerId bytes localityCost providerKind providerMu providerMi providerState
  use strict arg provider, bytes, localityCost
  numeric digits 20
  providerId=provider~providerId
  bytes=bytes+0
  localityCost=localityCost+0
  providerKind=provider~kind
  providerMu=provider~muId
  providerMi=provider~miId
  providerState=provider~providerState

::attribute providerId get
::attribute bytes get
::attribute localityCost get
::attribute providerKind get
::attribute providerMu get
::attribute providerMi get
::attribute providerState get


::class MemoryFabricCapacityPlan public

::method init
  expose requestedBytes fragments totalBytes complete worstLocality
  use strict arg requestedBytes
  numeric digits 20
  requestedBytes=requestedBytes+0
  fragments=.array~new
  totalBytes=0
  complete=.false
  worstLocality=0

::attribute requestedBytes get
::attribute totalBytes get
::attribute complete get
::attribute worstLocality get

::method addFragment
  expose fragments totalBytes requestedBytes complete worstLocality
  use strict arg fragment
  numeric digits 20
  fragments~append(fragment)
  totalBytes+=fragment~bytes
  if fragment~localityCost>worstLocality then worstLocality=fragment~localityCost
  complete=(totalBytes>=requestedBytes)
  return self

::method fragments
  expose fragments
  answer=.array~new
  do f over fragments
    answer~append(f)
  end
  return answer

::method providerCount
  expose fragments
  numeric digits 20
  return fragments~items


::class MemoryFabricCapacityPlanner public

::method init
  expose registry
  use strict arg registry
  numeric digits 20

::method plan
  expose registry
  use strict arg requesterMuId, requesterMachineId, requesterSiteId, requiredBytes, allowSpare=.false, maxProviders=8, maxLocality=100
  numeric digits 20
  need=requiredBytes+0
  if need<=0 then return .MemoryFabricCapacityPlan~new(need)

  plan=.MemoryFabricCapacityPlan~new(need)
  used=.directory~new

  do while plan~totalBytes<need & plan~providerCount<maxProviders
    best=.nil
    bestCost=999999
    bestAvail=-1

    do p over registry~providers
      if used[p~providerId]=.nil then do
        eligible=p~acceptsGeneralAllocation
        if allowSpare then eligible=eligible | p~eligibleAsSpare
        if eligible & p~availableBytes>0 then do
          cost=registry~localityCost(requesterMuId,requesterMachineId,requesterSiteId,p)
          if cost<=maxLocality then do
            if best=.nil | cost<bestCost | (cost=bestCost & p~availableBytes>bestAvail) then do
              best=p
              bestCost=cost
              bestAvail=p~availableBytes
            end
          end
        end
      end
    end

    if best=.nil then leave
    used[best~providerId]=1

    remaining=need-plan~totalBytes
    take=best~availableBytes
    if take>remaining then take=remaining
    plan~addFragment(.MemoryFabricCapacityFragment~new(best,take,bestCost))
  end

  return plan
