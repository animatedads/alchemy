/* ooRexx Storage Fabric v0.1-dev18
 * Mesh/RexxOS authority and estate SocketProvider integration.
 *
 * Storage owns storage semantics. RexxOS/RTO owns execution authority/epoch.
 * SocketAddressProvider/SocketProvider own addressing and native socket mechanics.
 */

::class StorageMeshBuild public
::constant VERSION "0.1-dev18"
::constant API "storage.fabric.mesh/0.1"

::class StorageMeshRole public
::constant ACTIVE "ACTIVE"
::constant SPARE "SPARE"
::constant REPLAY "REPLAY"
::constant FORENSIC "FORENSIC"

::class StorageMeshDecision public
::attribute allowed get
::attribute code get
::attribute reason get
::method init
  expose allowed code reason
  use strict arg allowedArg,codeArg,reasonArg=""
  allowed=(allowedArg==.true); code=codeArg~string; reason=reasonArg~string
::method permit class
  use strict arg codeArg="OK",reasonArg=""
  return self~new(.true,codeArg,reasonArg)
::method deny class
  use strict arg codeArg,reasonArg=""
  return self~new(.false,codeArg,reasonArg)

/* A projection of authority supplied by RexxOS/RTO2. It does not elect,
 * detect failure, or transfer authority. Promotion is accepted only as an
 * externally-authorised epoch transition. */
::class StorageMeshAuthority public
::attribute logicalService get
::attribute nodeId get
::attribute role get
::attribute epoch get
::attribute committedSequence get
::attribute observedAt get
::method init
  expose logicalService nodeId role epoch committedSequence observedAt
  use strict arg serviceArg,nodeArg,roleArg="SPARE",epochArg=0,committedArg=0,observedArg=""
  logicalService=serviceArg~string~strip
  nodeId=nodeArg~string~strip
  role=roleArg~string~strip~upper
  epoch=epochArg+0; committedSequence=committedArg+0; observedAt=observedArg~string
  if logicalService="" | nodeId="" then raise syntax 88.900 array("mesh service/node must not be empty")
  if \self~validRole(role) then raise syntax 88.900 array("invalid Storage mesh role")
::method validRole
  use strict arg value
  r=value~string~upper
  return r=.StorageMeshRole~ACTIVE | r=.StorageMeshRole~SPARE | r=.StorageMeshRole~REPLAY | r=.StorageMeshRole~FORENSIC
::method canRead
  expose role
  return role<>.StorageMeshRole~FORENSIC
::method canServePeerRead
  expose role
  return role=.StorageMeshRole~ACTIVE | role=.StorageMeshRole~SPARE | role=.StorageMeshRole~REPLAY
::method canMutate
  expose role
  return role=.StorageMeshRole~ACTIVE
::method canCommit
  expose role
  return role=.StorageMeshRole~ACTIVE
::method guardMutation
  expose role epoch
  use strict arg expectedEpoch=.nil
  if role<>.StorageMeshRole~ACTIVE then return .StorageMeshDecision~deny("NOT_ACTIVE","Storage mutation requires ACTIVE authority")
  if expectedEpoch<>.nil then if expectedEpoch+0<>epoch then return .StorageMeshDecision~deny("EPOCH_MISMATCH","Storage authority epoch changed")
  return .StorageMeshDecision~permit("ACTIVE_EPOCH")
::method observeCommit
  expose committedSequence role
  use strict arg sequenceArg
  seq=sequenceArg+0
  if seq<committedSequence then return .StorageMeshDecision~deny("COMMIT_REGRESSION","Committed sequence cannot move backwards")
  if role=.StorageMeshRole~FORENSIC then return .StorageMeshDecision~deny("FORENSIC_FROZEN","Forensic node cannot advance committed state")
  committedSequence=seq
  return .StorageMeshDecision~permit("COMMIT_OBSERVED")
::method acceptPromotion
  expose role epoch committedSequence
  use strict arg newEpoch,fromCommitted=.nil
  e=newEpoch+0
  if role=.StorageMeshRole~FORENSIC then return .StorageMeshDecision~deny("FORENSIC_FROZEN","Forensic node cannot be promoted")
  if e<=epoch then return .StorageMeshDecision~deny("STALE_EPOCH","Promotion epoch must advance")
  if fromCommitted<>.nil then do
    seq=fromCommitted+0
    if seq<committedSequence then return .StorageMeshDecision~deny("COMMIT_REGRESSION","Promotion cannot roll behind committed replay state")
    committedSequence=seq
  end
  epoch=e; role=.StorageMeshRole~ACTIVE
  return .StorageMeshDecision~permit("PROMOTED")
::method setReplicaRole
  expose role epoch
  use strict arg roleArg,epochArg=.nil
  r=roleArg~string~upper
  if r<>.StorageMeshRole~SPARE & r<>.StorageMeshRole~REPLAY & r<>.StorageMeshRole~FORENSIC then return .StorageMeshDecision~deny("INVALID_REPLICA_ROLE")
  if epochArg<>.nil then if epochArg+0<epoch then return .StorageMeshDecision~deny("STALE_EPOCH")
  if epochArg<>.nil then epoch=epochArg+0
  role=r
  return .StorageMeshDecision~permit("ROLE_UPDATED")

::class StorageMeshPeer public
::attribute nodeId get
::attribute logicalService get
::attribute role get
::attribute epoch get
::attribute evidence get
::method init
  expose nodeId logicalService role epoch evidence
  use strict arg nodeArg,serviceArg,roleArg="SPARE",epochArg=0,evidenceArg=.nil
  nodeId=nodeArg~string~strip; logicalService=serviceArg~string~strip
  role=roleArg~string~upper; epoch=epochArg+0; evidence=evidenceArg
  if nodeId="" | logicalService="" then raise syntax 88.900 array("mesh peer identity/service required")

::class StorageMeshPeerDirectory public
::method init
  expose peers
  peers=.directory~new
::method put
  expose peers
  use strict arg peer
  peers[peer~nodeId]=peer; return self
::method get
  expose peers
  use strict arg nodeId
  return peers[nodeId~string]
::method remove
  expose peers
  use strict arg nodeId
  peers~remove(nodeId~string); return self
::method all
  expose peers
  a=.array~new
  do p over peers; a~append(p); end
  return a
::method count
  expose peers
  return peers~items

/* Estate socket projection. The logical service name is resolved by the
 * injected SocketAddressProvider; SocketProvider remains the sole native
 * acquisition authority. No host, port, Unix path, XTP carrier or TLS key is
 * stored here. */
::class StoragePeerSocketPort public
::method init
  expose socketProvider addressProvider localService peerDirectory
  use strict arg socketProviderArg,addressProviderArg,localServiceArg,peerDirectoryArg=.nil
  socketProvider=socketProviderArg; addressProvider=addressProviderArg
  localService=localServiceArg~string~strip
  if peerDirectoryArg==.nil then peerDirectory=.StorageMeshPeerDirectory~new; else peerDirectory=peerDirectoryArg
  if socketProvider==.nil | addressProvider==.nil | localService="" then raise syntax 88.900 array("StoragePeerSocketPort requires estate socket provider/address provider/service")
::attribute peerDirectory get
::method peerAddress
  expose addressProvider peerDirectory
  use strict arg peerNodeId
  peer=peerDirectory~get(peerNodeId)
  if peer==.nil then return .nil
  return addressProvider~senderAddress(peer~logicalService)
::method sender
  expose socketProvider peerDirectory
  use strict arg peerNodeId
  peer=peerDirectory~get(peerNodeId)
  if peer==.nil then return .nil
  return socketProvider~streamSender(peer~logicalService)
::method listener
  expose socketProvider localService
  return socketProvider~listener(localService)
::method describePeer
  expose peerDirectory addressProvider
  use strict arg peerNodeId
  d=.directory~new
  peer=peerDirectory~get(peerNodeId)
  if peer==.nil then do; d["status"]="UNKNOWN_PEER"; return d; end
  d["status"]="RESOLVED"
  d["node_id"]=peer~nodeId; d["logical_service"]=peer~logicalService
  d["role"]=peer~role; d["epoch"]=peer~epoch
  address=addressProvider~senderAddress(peer~logicalService)
  if address==.nil then d["status"]="NO_ADDRESS"
  else do; d["address"]=address~canonical; d["family"]=address~family~addressFamily; end
  return d

/* Guards a StoragePeerService with mesh authority. Reads may be served by
 * ACTIVE/SPARE/REPLAY, but a FORENSIC node is frozen. Peer protocol itself is
 * still StoragePeerService authority. */
::class StorageMeshPeerService public
::method init
  expose authority delegate
  use strict arg authorityArg,delegateArg
  authority=authorityArg; delegate=delegateArg
::method handle
  expose authority delegate
  use strict arg request
  if \authority~canServePeerRead then return self~rejected(request,"NODE_FROZEN")
  return delegate~handle(request)
::method handleFrom
  expose authority delegate
  use strict arg authenticatedPeerId,request
  if \authority~canServePeerRead then return self~rejected(request,"NODE_FROZEN")
  return delegate~handleFrom(authenticatedPeerId,request)
::method rejected
  use strict arg request,code
  d=.directory~new; d["status"]="ERROR"; d["code"]=code
  if request<>.nil then if request~isA(.Directory) then if request~hasIndex("request_id") then d["request_id"]=request["request_id"]
  return d
