/* ooRexx Storage Fabric v0.1-dev18 — dynamic intention surface.
 * Discovery is recomputed for every call. Descriptors preserve native ooRexx
 * objects in context/results; no flattening to a foreign action catalogue.
 */

::class StorageIntentionBuild public
::constant VERSION "0.1-dev18"
::constant API "storage.fabric.intentions/0.1"

::class StorageIntentionRisk public
::constant READ "READ"
::constant CHANGE "CHANGE"
::constant DESTRUCTIVE "DESTRUCTIVE"
::constant AUTHORITY "AUTHORITY"

::class StorageIntentionName public
::constant STATUS "STORAGE_STATUS"
::constant SEARCH "STORAGE_SEARCH"
::constant CAPACITY "STORAGE_CAPACITY"
::constant PROVIDERS "STORAGE_PROVIDERS"
::constant OBJECT "STORAGE_OBJECT"
::constant LOCATIONS "STORAGE_LOCATIONS"
::constant NAMESPACE_LIST "STORAGE_NAMESPACE_LIST"
::constant NAMESPACE_RESOLVE "STORAGE_NAMESPACE_RESOLVE"
::constant PEERS "STORAGE_PEERS"
::constant PEER_EXPLAIN "STORAGE_PEER_EXPLAIN"
::constant REPLICA_STATUS "STORAGE_REPLICA_STATUS"
::constant TRANSFER_STATUS "STORAGE_TRANSFER_STATUS"
::constant BIND "STORAGE_BIND"
::constant UNBIND "STORAGE_UNBIND"
::constant ALIAS_ADD "STORAGE_ALIAS_ADD"
::constant ALIAS_REMOVE "STORAGE_ALIAS_REMOVE"
::constant PROVIDER_ATTACH "STORAGE_PROVIDER_ATTACH"
::constant PROVIDER_DETACH "STORAGE_PROVIDER_DETACH"
::constant REPLICA_MATERIALISE "STORAGE_REPLICA_MATERIALISE"
::constant REPLICA_ADMIT "STORAGE_REPLICA_ADMIT"
::constant REPLICA_EVICT "STORAGE_REPLICA_EVICT"
::constant SNAPSHOT "STORAGE_SNAPSHOT"
::constant PROMOTE "STORAGE_PROMOTE"
::constant TRANSFER "STORAGE_TRANSFER"
::constant TRANSFER_RESUME "STORAGE_TRANSFER_RESUME"
::constant MEDIA_IMPORT "STORAGE_MEDIA_IMPORT"
::constant MEDIA_EXPORT "STORAGE_MEDIA_EXPORT"
::constant CHECKPOINT_MOVE "STORAGE_CHECKPOINT_MOVE"
::constant PEER_PUBLISH "STORAGE_PEER_PUBLISH"
::constant PEER_WITHDRAW "STORAGE_PEER_WITHDRAW"
::constant PROMOTE_NODE "STORAGE_PROMOTE_NODE"

::class StorageIntentionDescriptor public
::attribute name get
::attribute phrase get
::attribute description get
::attribute risk get
::attribute operation get
::attribute slots get
::attribute capability get
::method init
  expose name phrase description risk operation slots capability
  use strict arg nameArg,phraseArg,descriptionArg,riskArg="READ",operationArg="",slotsArg=.nil,capabilityArg=""
  name=nameArg~string~strip~upper; phrase=phraseArg~string; description=descriptionArg~string
  risk=riskArg~string~upper; operation=operationArg~string; capability=capabilityArg~string
  if slotsArg==.nil then slots=.array~new; else slots=slotsArg
::method requires
  expose slots
  use strict arg slotName
  slots~append(slotName~string~upper); return self

/* Surface adapter deliberately small: a resident Storage engine may expose
 * capabilities() and invokeStorageIntention(). Tests and management discovery
 * can provide the same shape without importing the engine implementation. */
::class StorageIntentionPort public
::method init
  expose surface meshAuthority peerDirectory
  use strict arg surfaceArg,meshAuthorityArg=.nil,peerDirectoryArg=.nil
  surface=surfaceArg; meshAuthority=meshAuthorityArg
  if peerDirectoryArg==.nil then peerDirectory=.StorageMeshPeerDirectory~new; else peerDirectory=peerDirectoryArg
::attribute surface get
::method discover
  expose surface meshAuthority
  use strict arg context=.nil
  caps=self~capabilities(context)
  out=.array~new
  /* universal read-side management */
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~STATUS,"show storage status","Show Storage Fabric authority, health and generation state",.StorageIntentionRisk~READ,"status",.nil,"STATUS"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~SEARCH,"find storage objects","Search the authoritative Storage catalogue",.StorageIntentionRisk~READ,"search",self~slots("QUERY"),"SEARCH"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~CAPACITY,"show storage capacity","Show capacity domains, pools and reservations",.StorageIntentionRisk~READ,"capacity",.nil,"CAPACITY"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PROVIDERS,"show storage providers","Show currently available storage providers and lifecycle",.StorageIntentionRisk~READ,"providers",.nil,"PROVIDERS"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~OBJECT,"show storage object","Show StorageRef metadata",.StorageIntentionRisk~READ,"object",self~slots("OBJECT"),"OBJECT"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~LOCATIONS,"show object locations","Show verified/admitted locations for a StorageRef",.StorageIntentionRisk~READ,"locations",self~slots("OBJECT"),"LOCATIONS"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~NAMESPACE_LIST,"list storage namespace","List a Storage namespace/environment",.StorageIntentionRisk~READ,"namespace.list",self~slots("PATH"),"NAMESPACE"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~NAMESPACE_RESOLVE,"resolve storage path","Resolve pathname projection to StorageRef without changing it",.StorageIntentionRisk~READ,"namespace.resolve",self~slots("PATH"),"NAMESPACE"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PEERS,"show storage peers","Show mesh peers and current roles/epochs",.StorageIntentionRisk~READ,"peers",.nil,"PEERS"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PEER_EXPLAIN,"explain storage peer route","Explain logical service/socket-family resolution for a peer",.StorageIntentionRisk~READ,"peer.explain",self~slots("PEER"),"PEERS"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~REPLICA_STATUS,"show replica status","Show replica safety/durability evidence",.StorageIntentionRisk~READ,"replica.status",self~slots("OBJECT"),"REPLICA"))
  self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~TRANSFER_STATUS,"show transfer status","Show resumable transfer/checkpoint state",.StorageIntentionRisk~READ,"transfer.status",self~slots("TRANSFER"),"TRANSFER"))

  /* Mutations are discoverable only while this node has current ACTIVE
   * authority. This is intentionally stricter than hiding them at dispatch. */
  active=.true
  if meshAuthority<>.nil then active=meshAuthority~canMutate
  if active then do
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~BIND,"bind storage path","Bind a namespace path to a StorageRef",.StorageIntentionRisk~CHANGE,"namespace.bind",self~slots("PATH","OBJECT"),"NAMESPACE_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~UNBIND,"unbind storage path","Remove a namespace binding",.StorageIntentionRisk~DESTRUCTIVE,"namespace.unbind",self~slots("PATH"),"NAMESPACE_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~ALIAS_ADD,"add storage alias","Create a namespace alias",.StorageIntentionRisk~CHANGE,"namespace.alias.add",self~slots("PATH","TARGET"),"NAMESPACE_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~ALIAS_REMOVE,"remove storage alias","Remove a namespace alias",.StorageIntentionRisk~DESTRUCTIVE,"namespace.alias.remove",self~slots("PATH"),"NAMESPACE_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PROVIDER_ATTACH,"attach storage provider","Attach/configure a provider through resident Storage authority",.StorageIntentionRisk~CHANGE,"provider.attach",self~slots("PROVIDER"),"PROVIDER_ADMIN"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PROVIDER_DETACH,"detach storage provider","Detach a provider after safety checks",.StorageIntentionRisk~DESTRUCTIVE,"provider.detach",self~slots("PROVIDER"),"PROVIDER_ADMIN"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~REPLICA_MATERIALISE,"materialise storage replica","Copy a StorageRef from a peer/provider and verify it",.StorageIntentionRisk~CHANGE,"replica.materialise",self~slots("OBJECT","TARGET"),"REPLICA_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~REPLICA_ADMIT,"admit storage replica","Admit independently verified bytes as a Storage location",.StorageIntentionRisk~CHANGE,"replica.admit",self~slots("OBJECT","LOCATION"),"REPLICA_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~REPLICA_EVICT,"evict storage replica","Remove a location only after durability policy proves it safe",.StorageIntentionRisk~DESTRUCTIVE,"replica.evict",self~slots("OBJECT","LOCATION"),"REPLICA_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~SNAPSHOT,"snapshot storage environment","Create/publish an environment generation snapshot",.StorageIntentionRisk~CHANGE,"snapshot",self~slots("ENVIRONMENT"),"SNAPSHOT"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PROMOTE,"promote storage generation","Promote a prepared generation/change set",.StorageIntentionRisk~AUTHORITY,"generation.promote",self~slots("ENVIRONMENT","GENERATION"),"SNAPSHOT"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~TRANSFER,"transfer storage object","Start verified provider-neutral byte movement",.StorageIntentionRisk~CHANGE,"transfer",self~slots("OBJECT","TARGET"),"TRANSFER_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~TRANSFER_RESUME,"resume storage transfer","Resume from a fenced transfer checkpoint",.StorageIntentionRisk~CHANGE,"transfer.resume",self~slots("TRANSFER"),"TRANSFER_WRITE"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~MEDIA_IMPORT,"import storage media","Import card/paper/tape or virtual-media edge representation",.StorageIntentionRisk~CHANGE,"media.import",self~slots("SOURCE","MEDIA_TYPE"),"MEDIA"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~MEDIA_EXPORT,"export storage media","Project canonical storage media to an edge format",.StorageIntentionRisk~CHANGE,"media.export",self~slots("OBJECT","TARGET","MEDIA_TYPE"),"MEDIA"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~CHECKPOINT_MOVE,"move execution checkpoint","Move a migratable-job checkpoint without changing job semantics",.StorageIntentionRisk~CHANGE,"checkpoint.move",self~slots("OBJECT","TARGET_NODE"),"CHECKPOINT"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PEER_PUBLISH,"publish storage object to peers","Publish peer availability evidence for a StorageRef",.StorageIntentionRisk~CHANGE,"peer.publish",self~slots("OBJECT"),"PEER_ADMIN"))
    self~add(out,caps,.StorageIntentionDescriptor~new(.StorageIntentionName~PEER_WITHDRAW,"withdraw storage peer export","Withdraw peer availability without deleting the object",.StorageIntentionRisk~CHANGE,"peer.withdraw",self~slots("OBJECT"),"PEER_ADMIN"))
  end
  return out
::method capabilities
  expose surface
  use strict arg context=.nil
  if surface==.nil then return .nil
  if surface~hasMethod("CAPABILITIES") then return surface~capabilities(context)
  return .nil
::method add
  use strict arg out,caps,descriptor
  if caps==.nil then do; out~append(descriptor); return; end
  if caps~isA(.Directory) then do
    if caps~hasIndex(descriptor~capability) then if caps[descriptor~capability] then out~append(descriptor)
    return
  end
  out~append(descriptor)
::method slots
  use arg a1="",a2="",a3="",a4=""
  a=.array~new
  do x over .array~of(a1,a2,a3,a4)
    if x<>"" then a~append(x)
  end
  return a
::method find
  use strict arg name,context=.nil
  key=name~string~strip~upper
  do d over self~discover(context)
    if d~name=key then return d
  end
  return .nil
::method invoke
  expose surface meshAuthority
  use strict arg intentionName,arguments=.nil,context=.nil,expectedEpoch=.nil
  descriptor=self~find(intentionName,context)
  if descriptor==.nil then return self~result(.false,"UNAVAILABLE","Intention is not currently discoverable")
  if descriptor~risk<>.StorageIntentionRisk~READ & meshAuthority<>.nil then do
    guard=meshAuthority~guardMutation(expectedEpoch)
    if \guard~allowed then return self~result(.false,guard~code,guard~reason)
  end
  if surface==.nil | \surface~hasMethod("INVOKESTORAGEINTENTION") then return self~result(.false,"NO_AUTHORITY_SURFACE","No resident Storage management surface is bound")
  return surface~invokeStorageIntention(descriptor~operation,arguments,context)
::method result
  use strict arg ok,code,reason=""
  d=.directory~new; d["ok"]=(ok==.true); d["code"]=code; d["reason"]=reason; return d

/* Adapter shape for Management Intention Discovery / Intention Service. It
 * intentionally owns no conversational or NLP state. */
::class StorageDynamicIntentionProvider public
::method init
  expose port
  use strict arg portArg
  port=portArg
::method discover
  expose port
  use strict arg context=.nil
  return port~discover(context)
::method invoke
  expose port
  use strict arg intentionName,arguments=.nil,context=.nil,expectedEpoch=.nil
  return port~invoke(intentionName,arguments,context,expectedEpoch)

::requires "StorageMesh.cls"
