/* IdentityPeerFabric.cls - logical peer replication for v0.1-dev13. */

::class IdentityPeerFabricBuild public
::constant API_VERSION "identity.peer.update/0.1"
::constant CODEC_VERSION "identity.peer.update-json/0.1"
::constant EPOCH_API "identity.peer.epoch/0.1"
::constant OUTBOX_API "identity.peer.outbox/0.1"
::constant TRANSPORT_API "identity.peer.transport/0.1"
::constant MULTICAST_CHANNEL_API "identity.peer.multicast.channel/0.1"
::constant ACK_CODEC_VERSION "identity.peer.ack-json/0.1"

::class IdentityPeerCommitPolicy public
::constant LOCAL_COMMITTED "LOCAL_COMMITTED"
::constant QUORUM_COMMITTED "QUORUM_COMMITTED"
::constant ALL_TARGETS_COMMITTED "ALL_TARGETS_COMMITTED"
::method normalized class
  use strict arg policy
  p = policy~string~strip~upper
  if p = self~LOCAL_COMMITTED | p = self~QUORUM_COMMITTED | p = self~ALL_TARGETS_COMMITTED then return p
  raise syntax 88.900 array("unsupported identity peer commit policy:" policy)
::method requiredRemoteAcks class
  use strict arg policy, targetCount
  p = self~normalized(policy)
  n = targetCount + 0
  if n < 0 then n = 0
  if p = self~LOCAL_COMMITTED then return 0
  if p = self~ALL_TARGETS_COMMITTED then return n
  cluster = n + 1
  majority = trunc(cluster / 2) + 1
  remote = majority - 1
  if remote < 0 then remote = 0
  return remote

/* Epoch fencing is a control-plane authority.  Old epochs are replayable only
 * through the sequence that was durably committed before promotion. */
::class IdentityPeerEpochAuthority public
::method init
  expose currentEpoch currentStart sealedStart sealedMax
  currentEpoch = .directory~new
  currentStart = .directory~new
  sealedStart = .directory~new
  sealedMax = .directory~new
::method key private
  use strict arg peerId, epoch
  return peerId~string || "|" || epoch
::method activate
  expose currentEpoch currentStart
  use strict arg peerId, epoch, startSequence = 1
  peer = peerId~string; e = epoch + 0; start = startSequence + 0
  if peer = "" | e < 1 | start < 1 then return .DirectoryResult~failure("PEER_EPOCH_INVALID")
  if currentEpoch~hasIndex(peer) then do
    if currentEpoch[peer] = e & currentStart[peer] = start then return .DirectoryResult~success(.false,"EPOCH_ALREADY_ACTIVE")
    return .DirectoryResult~failure("PEER_EPOCH_ALREADY_ACTIVE", currentEpoch[peer])
  end
  currentEpoch[peer] = e; currentStart[peer] = start
  return .DirectoryResult~success(.true,"EPOCH_ACTIVE")
::method promote
  expose currentEpoch currentStart sealedStart sealedMax
  use strict arg peerId, newEpoch, lastCommittedSequence
  peer = peerId~string
  if \currentEpoch~hasIndex(peer) then return .DirectoryResult~failure("PEER_EPOCH_NOT_ACTIVE",peer)
  old = currentEpoch[peer]; next = newEpoch + 0; last = lastCommittedSequence + 0
  if next <= old then return .DirectoryResult~failure("PEER_EPOCH_NOT_MONOTONIC",old || "/" || next)
  start = currentStart[peer]
  if last < start - 1 then return .DirectoryResult~failure("PEER_EPOCH_SEAL_INVALID",last)
  k = self~key(peer,old); sealedStart[k] = start; sealedMax[k] = last
  currentEpoch[peer] = next; currentStart[peer] = last + 1
  return .DirectoryResult~success(next,"EPOCH_PROMOTED")
::method authorize
  expose currentEpoch currentStart sealedStart sealedMax
  use strict arg peerId, epoch, sequence
  peer = peerId~string; e = epoch + 0; seq = sequence + 0
  if currentEpoch~hasIndex(peer) then if currentEpoch[peer] = e then do
    if seq >= currentStart[peer] then return .DirectoryResult~success(.true,"CURRENT_EPOCH")
    return .DirectoryResult~failure("PEER_SEQUENCE_BEFORE_EPOCH",seq)
  end
  k = self~key(peer,e)
  if sealedMax~hasIndex(k) then do
    if seq >= sealedStart[k] & seq <= sealedMax[k] then return .DirectoryResult~success(.true,"SEALED_EPOCH_REPLAY")
    return .DirectoryResult~failure("STALE_EPOCH_SEQUENCE_OUTSIDE_SEAL",seq)
  end
  if currentEpoch~hasIndex(peer) then return .DirectoryResult~failure("PEER_EPOCH_NOT_AUTHORIZED",e || "/current=" || currentEpoch[peer])
  return .DirectoryResult~failure("PEER_EPOCH_UNKNOWN",peer)
::method current
  expose currentEpoch
  use strict arg peerId
  if currentEpoch~hasIndex(peerId~string) then return currentEpoch[peerId~string]
  return 0
::method currentStartSequence
  expose currentStart
  use strict arg peerId
  if currentStart~hasIndex(peerId~string) then return currentStart[peerId~string]
  return 0

::class IdentityPeerUpdateRequest public
::attribute requestId get
::attribute originPeerId get
::attribute originEpoch get
::attribute change get
::attribute targets get
::attribute commitPolicy get
::attribute createdAt get
::method init
  expose requestId originPeerId originEpoch change targets commitPolicy createdAt
  use strict arg originEpochArg, changeArg, targetsArg, commitPolicyArg = "QUORUM_COMMITTED", requestIdArg = "", createdAtArg = (.DateTime~new)
  if changeArg == .nil then raise syntax 88.900 array("peer update change required")
  change = changeArg; originPeerId = change~originPeerId; originEpoch = originEpochArg + 0
  if originEpoch < 1 then raise syntax 88.900 array("peer update epoch must be positive")
  commitPolicy = .IdentityPeerCommitPolicy~normalized(commitPolicyArg)
  createdAt = .DirectoryCanonical~requireDateTime("createdAt",createdAtArg)
  targets = .array~new; seen = .directory~new
  do target over targetsArg
    t = target~string
    if t = "" | t = originPeerId then iterate
    if \seen~hasIndex(t) then do; seen[t] = .true; targets~append(t); end
  end
  targets = .DirectoryCanonical~sortedStrings(targets)
  if requestIdArg~string = "" then requestId = originPeerId || ":epoch=" || originEpoch || ":change=" || change~changeId
  else requestId = requestIdArg~string
::method hasTarget
  expose targets
  use strict arg peerId
  p = peerId~string
  do t over targets; if t = p then return .true; end
  return .false
::method canonicalText
  expose requestId originPeerId originEpoch change targets commitPolicy
  text = "IDENTITY-PEER-UPDATE/1" || '0a'x
  text ||= .DirectoryCanonical~field("REQUEST_ID",requestId)
  text ||= .DirectoryCanonical~field("ORIGIN_PEER_ID",originPeerId)
  text ||= .DirectoryCanonical~field("ORIGIN_EPOCH",originEpoch)
  text ||= .DirectoryCanonical~field("CHANGE_IDENTITY",change~semanticIdentity)
  text ||= .DirectoryCanonical~field("COMMIT_POLICY",commitPolicy)
  do t over targets; text ||= .DirectoryCanonical~field("TARGET",t); end
  return text
::method semanticIdentity
  return .DirectoryCanonical~hash(self~canonicalText)

::class IdentityPeerUpdateCodec public
::method sv class
  use strict arg value = ""
  if value == .nil then value = ""
  return .JsonString~new(value~string)
::method toRecord class
  use strict arg request
  r = .directory~new
  r["codec"] = self~sv(.IdentityPeerFabricBuild~CODEC_VERSION)
  r["requestId"] = self~sv(request~requestId)
  r["requestIdentity"] = self~sv(request~semanticIdentity)
  r["originPeerId"] = self~sv(request~originPeerId)
  r["originEpoch"] = request~originEpoch
  r["commitPolicy"] = self~sv(request~commitPolicy)
  r["createdAt"] = self~sv(.DirectoryCanonical~dateTimeText(request~createdAt))
  ts = .array~new; do t over request~targets; ts~append(self~sv(t)); end; r["targets"] = ts
  r["change"] = .DirectoryChangeCodec~toRecord(request~change)
  return r
::method toJson class
  use strict arg request
  return .json~toJSON(self~toRecord(request))
::method fromRecord class
  use strict arg r
  if r["codec"] == .nil then raise syntax 88.900 array("peer update codec missing")
  if r["codec"]~string <> .IdentityPeerFabricBuild~CODEC_VERSION then raise syntax 88.900 array("unsupported peer update codec")
  ts = .array~new; if r["targets"] <> .nil then do t over r["targets"]; ts~append(t~string); end
  ch = .DirectoryChangeCodec~fromRecord(r["change"])
  dt = .DirectoryEntityCodec~requiredDateTimeFromText("peerUpdate.createdAt",r["createdAt"])
  req = .IdentityPeerUpdateRequest~new(r["originEpoch"],ch,ts,r["commitPolicy"]~string,r["requestId"]~string,dt)
  if req~originPeerId <> r["originPeerId"]~string then raise syntax 88.900 array("peer update origin mismatch")
  if req~semanticIdentity <> r["requestIdentity"]~string then raise syntax 88.900 array("peer update identity mismatch")
  return req
::method fromJson class
  use strict arg text
  return self~fromRecord(.json~fromJSON(text~string))

::class IdentityPeerAck public
::attribute requestId get
::attribute peerId get
::attribute status get
::attribute detail get
::attribute durableRevision get
::attribute ackedAt get
::method init
  expose requestId peerId status detail durableRevision ackedAt
  use strict arg requestIdArg, peerIdArg, statusArg, detailArg = "", durableRevisionArg = 0, ackedAtArg = (.DateTime~new)
  requestId=requestIdArg~string; peerId=peerIdArg~string; status=statusArg~string~upper; detail=detailArg~string
  durableRevision=durableRevisionArg+0; ackedAt=.DirectoryCanonical~requireDateTime("ackedAt",ackedAtArg)
::method ok
  expose status
  return status = "APPLIED" | status = "ALREADY_APPLIED" | status = "SEMANTICALLY_PRESENT" | status = "ALREADY_ABSENT"

::class IdentityPeerOutbox public
::method apiVersion
  return .IdentityPeerFabricBuild~OUTBOX_API
::method recordRequest abstract
::method recordAck abstract
::method loadRequests abstract
::method loadAcks abstract
::method capabilities
  d=.directory~new; d["durable"]=.false; d["requestIdentityGuard"]=.true; return d

::class MemoryIdentityPeerOutbox subclass IdentityPeerOutbox public
::method init
  expose requests identities acks
  requests=.array~new; identities=.directory~new; acks=.directory~new
::method recordRequest
  expose requests identities
  use strict arg request
  id=request~requestId
  if identities~hasIndex(id) then do
    if identities[id]=request~semanticIdentity then return .DirectoryResult~success(.false,"REQUEST_ALREADY_STORED")
    return .DirectoryResult~failure("PEER_REQUEST_DIVERGED",id)
  end
  copy=.IdentityPeerUpdateCodec~fromJson(.IdentityPeerUpdateCodec~toJson(request))
  requests~append(copy); identities[id]=copy~semanticIdentity
  return .DirectoryResult~success(.true,"REQUEST_STORED")
::method recordAck
  expose acks
  use strict arg ack
  acks[ack~requestId || "|" || ack~peerId] = ack
  return .DirectoryResult~success(.true,"ACK_STORED")
::method loadRequests
  expose requests
  out=.array~new; do r over requests; out~append(.IdentityPeerUpdateCodec~fromJson(.IdentityPeerUpdateCodec~toJson(r))); end
  return .DirectoryResult~success(out,"REQUESTS_LOADED")
::method loadAcks
  expose acks
  use strict arg requestId
  out=.array~new; prefix=requestId~string || "|"
  do k over acks~allIndexes; if left(k,length(prefix))=prefix then out~append(acks[k]); end
  return .DirectoryResult~success(out,"ACKS_LOADED")

::class IdentityPeerReceiver public
::attribute peerId get
::attribute directory get
::method init
  expose peerId directory epochAuthority
  use strict arg peerIdArg, directoryArg, epochAuthorityArg
  peerId=peerIdArg~string; directory=directoryArg; epochAuthority=epochAuthorityArg
::method receive
  expose peerId directory epochAuthority
  use strict arg request
  if request == .nil then return .IdentityPeerAck~new("",peerId,"REJECTED","REQUEST_REQUIRED",directory~revision)
  if \request~hasTarget(peerId) then return .IdentityPeerAck~new(request~requestId,peerId,"REJECTED","PEER_NOT_TARGETED",directory~revision)
  ch=request~change
  auth=epochAuthority~authorize(request~originPeerId,request~originEpoch,ch~originSequence)
  if \auth~ok then return .IdentityPeerAck~new(request~requestId,peerId,"REJECTED",auth~code || ":" || auth~detail,directory~revision)
  applied=directory~applyReplicatedChange(ch)
  if \applied~ok then return .IdentityPeerAck~new(request~requestId,peerId,"REJECTED",applied~code || ":" || applied~detail,directory~revision)
  return .IdentityPeerAck~new(request~requestId,peerId,applied~detail,"",directory~revision)

::class IdentityPeerAckCodec public
::method sv class
  use strict arg value = ""
  if value == .nil then value = ""
  return .JsonString~new(value~string)
::method toRecord class
  use strict arg ack
  r=.directory~new
  r["codec"]=self~sv(.IdentityPeerFabricBuild~ACK_CODEC_VERSION)
  r["requestId"]=self~sv(ack~requestId)
  r["peerId"]=self~sv(ack~peerId)
  r["status"]=self~sv(ack~status)
  r["detail"]=self~sv(ack~detail)
  r["durableRevision"]=ack~durableRevision
  r["ackedAt"]=self~sv(.DirectoryCanonical~dateTimeText(ack~ackedAt))
  return r
::method toJson class
  use strict arg ack
  return .json~toJSON(self~toRecord(ack))
::method fromRecord class
  use strict arg r
  if r["codec"] == .nil then raise syntax 88.900 array("peer ACK codec missing")
  if r["codec"]~string <> .IdentityPeerFabricBuild~ACK_CODEC_VERSION then raise syntax 88.900 array("unsupported peer ACK codec")
  dt=.DirectoryEntityCodec~requiredDateTimeFromText("peerAck.ackedAt",r["ackedAt"])
  return .IdentityPeerAck~new(r["requestId"]~string,r["peerId"]~string,r["status"]~string,r["detail"]~string,r["durableRevision"],dt)
::method fromJson class
  use strict arg text
  return self~fromRecord(.json~fromJSON(text~string))

/* A native multicast carrier publishes one immutable semantic request once.
 * ACKs remain per-peer application evidence; they are not inferred from
 * carrier delivery.  The channel therefore has an explicit ACK collection
 * seam.  A concrete carrier may use NORM/IP multicast for publish and a
 * separate unicast/control path for ACK ingress. */
::class IdentityPeerMulticastChannel public
::method apiVersion
  return .IdentityPeerFabricBuild~MULTICAST_CHANNEL_API
::method publish abstract
::method collectAcks abstract

/* SocketProvider bridge for the multicast publication half.  The selected
 * SocketAddress object is authoritative and must itself be multicast-capable.
 * NORM session/group/FEC mechanics stay below SocketProvider. */
::class SocketProviderIdentityPeerMulticastChannel subclass IdentityPeerMulticastChannel public
::method init
  expose provider address ackCollector
  use strict arg providerArg, addressArg, ackCollectorArg
  if providerArg == .nil | addressArg == .nil | ackCollectorArg == .nil then raise syntax 88.900 array("multicast channel requires provider, address and ACK collector")
  if \addressArg~multicast then raise syntax 88.900 array("identity peer multicast requires multicast SocketAddress")
  provider=providerArg; address=addressArg; ackCollector=ackCollectorArg
::attribute address get
::method publish
  expose provider address
  use strict arg request, targetIds
  endpoint=provider~senderAt(address)
  if endpoint == .nil then return .DirectoryResult~failure("PEER_MULTICAST_NO_SENDER",address~canonical)
  payload=.IdentityPeerUpdateCodec~toJson(request)
  sent=endpoint~send(payload)
  if endpoint~hasMethod("WAITDRAINED") then ignore=endpoint~waitDrained(5000)
  ignore=endpoint~close
  if sent == .nil then return .DirectoryResult~failure("PEER_MULTICAST_SEND_FAILED")
  if datatype(sent,"W") then if sent < length(payload) then return .DirectoryResult~failure("PEER_MULTICAST_SHORT_SEND",sent || "/" || length(payload))
  return .DirectoryResult~success(targetIds~items,"PEER_MULTICAST_PUBLISHED")
::method collectAcks
  expose ackCollector
  use strict arg request, targetIds
  return ackCollector~collect(request,targetIds)

/* Qualification channel: it models one carrier publication while preserving
 * real receiver validation and per-peer ACKs.  This is not a network mock of
 * NORM; it proves the semantic multicast/ACK contract independently of any
 * carrier implementation. */
::class MemoryIdentityPeerMulticastChannel subclass IdentityPeerMulticastChannel public
::method init
  expose receivers blocked publications ackSets
  receivers=.directory~new; blocked=.directory~new; publications=0; ackSets=.directory~new
::attribute publications get
::method register
  expose receivers
  use strict arg peerId, receiver
  receivers[peerId~string]=receiver; return self
::method setAvailable
  expose blocked
  use strict arg peerId, available=.true
  p=peerId~string
  if available then do; if blocked~hasIndex(p) then blocked~remove(p); end
  else blocked[p]=.true
  return self
::method publish
  expose receivers blocked publications ackSets
  use strict arg request, targetIds
  publications += 1
  acks=.array~new
  do peerId over targetIds
    p=peerId~string
    if blocked~hasIndex(p) | \receivers~hasIndex(p) then iterate
    acks~append(receivers[p]~receive(request))
  end
  ackSets[request~requestId]=acks
  return .DirectoryResult~success(targetIds~items,"PEER_MULTICAST_PUBLISHED")
::method collectAcks
  expose ackSets
  use strict arg request, targetIds
  out=.array~new; wanted=.directory~new
  do p over targetIds; wanted[p~string]=.true; end
  if \ackSets~hasIndex(request~requestId) then return out
  do ack over ackSets[request~requestId]
    if wanted~hasIndex(ack~peerId) then out~append(ack)
  end
  return out

::class IdentityPeerTransport public
::method apiVersion
  return .IdentityPeerFabricBuild~TRANSPORT_API
::method nativeMulticast
  return .false
::method send abstract
::method multicast
  use strict arg request, targetIds
  out=.array~new
  do peerId over targetIds
    ack=self~send(request,peerId)
    if ack <> .nil then out~append(ack)
  end
  return out

/* Native multicast is used only for the first full fan-out.  Durable retry of
 * a subset deliberately falls back to targeted unicast so an already-ACKed
 * peer is not needlessly redelivered just because it shares the group. */
::class IdentityPeerNativeMulticastTransport subclass IdentityPeerTransport public
::method init
  expose channel fallback
  use strict arg channelArg, fallbackArg=.nil
  if channelArg == .nil then raise syntax 88.900 array("native multicast channel required")
  channel=channelArg; fallback=fallbackArg
::attribute channel get
::method nativeMulticast
  return .true
::method send
  expose fallback
  use strict arg request, peerId
  if fallback == .nil then return .nil
  return fallback~send(request,peerId)
::method sameTargets private
  use strict arg leftTargets, rightTargets
  if leftTargets~items <> rightTargets~items then return .false
  seen=.directory~new; do p over leftTargets; seen[p~string]=.true; end
  do p over rightTargets; if \seen~hasIndex(p~string) then return .false; end
  return .true
::method multicast
  expose channel fallback
  use strict arg request, targetIds
  if targetIds~items=0 then return .array~new
  if \self~sameTargets(request~targets,targetIds) then do
    if fallback == .nil then return .array~new
    return fallback~multicast(request,targetIds)
  end
  published=channel~publish(request,targetIds)
  if published == .nil then return .array~new
  if published~hasMethod("OK") then if \published~ok then return .array~new
  return channel~collectAcks(request,targetIds)

::class MemoryIdentityPeerTransport subclass IdentityPeerTransport public
::method init
  expose receivers blocked sends
  receivers=.directory~new; blocked=.directory~new; sends=0
::attribute sends get
::method register
  expose receivers
  use strict arg peerId, receiver
  receivers[peerId~string]=receiver; return self
::method setAvailable
  expose blocked
  use strict arg peerId, available=.true
  p=peerId~string
  if available then do; if blocked~hasIndex(p) then blocked~remove(p); end
  else blocked[p]=.true
  return self
::method send
  expose receivers blocked sends
  use strict arg request, peerId
  p=peerId~string; sends += 1
  if blocked~hasIndex(p) | \receivers~hasIndex(p) then return .nil
  return receivers[p]~receive(request)

::class IdentityPeerCoordinator public
::method init
  expose directory peerId epochAuthority transport outbox
  use strict arg directoryArg, epochAuthorityArg, transportArg, outboxArg = .nil
  directory=directoryArg; peerId=directory~peerId; epochAuthority=epochAuthorityArg; transport=transportArg
  if outboxArg == .nil then outbox=.MemoryIdentityPeerOutbox~new; else outbox=outboxArg
::attribute outbox get
::method multicastChange
  expose peerId epochAuthority transport outbox
  use strict arg change, originEpoch, targets, commitPolicy = "QUORUM_COMMITTED"
  if change == .nil then return .DirectoryResult~failure("CHANGE_REQUIRED")
  if change~originPeerId <> peerId then return .DirectoryResult~failure("NOT_LOCAL_ORIGIN",change~originPeerId)
  auth=epochAuthority~authorize(peerId,originEpoch,change~originSequence); if \auth~ok then return auth
  req=.IdentityPeerUpdateRequest~new(originEpoch,change,targets,commitPolicy)
  stored=outbox~recordRequest(req); if \stored~ok then return stored
  acks=transport~multicast(req,req~targets); do ack over acks; ignore=outbox~recordAck(ack); end
  return self~evaluate(req,acks)
::method evaluate private
  use strict arg request, acks
  good=0; rejected=0
  do ack over acks; if ack~ok then good+=1; else rejected+=1; end
  required=.IdentityPeerCommitPolicy~requiredRemoteAcks(request~commitPolicy,request~targets~items)
  state=.directory~new; state["requestId"]=request~requestId; state["requestIdentity"]=request~semanticIdentity
  state["policy"]=request~commitPolicy; state["targetCount"]=request~targets~items; state["ackCount"]=good
  state["rejectedCount"]=rejected; state["requiredRemoteAcks"]=required
  if good >= required then do
    if good = request~targets~items then state["state"]="ALL_TARGETS_COMMITTED"
    else if request~commitPolicy=.IdentityPeerCommitPolicy~LOCAL_COMMITTED then state["state"]="LOCAL_COMMITTED"
    else state["state"]="QUORUM_COMMITTED"
    return .DirectoryResult~success(state,state["state"])
  end
  state["state"]="DEGRADED_PENDING"
  return .DirectoryResult~failure("PEER_COMMIT_PENDING",good || "/" || required)
::method retryOutstanding
  expose transport outbox
  loaded=outbox~loadRequests; if \loaded~ok then return loaded
  results=.array~new
  do request over loaded~value
    old=outbox~loadAcks(request~requestId); if \old~ok then return old
    completed=.directory~new; do ack over old~value; if ack~ok then completed[ack~peerId]=.true; end
    pending=.array~new; do p over request~targets; if \completed~hasIndex(p) then pending~append(p); end
    fresh=transport~multicast(request,pending); do ack over fresh; ignore=outbox~recordAck(ack); end
    all=.array~new; do ack over old~value; all~append(ack); end; do ack over fresh; all~append(ack); end
    results~append(self~evaluate(request,all))
  end
  return .DirectoryResult~success(results,"OUTSTANDING_RETRIED")

::requires "src/DirectoryStore.cls"
::requires "json.cls"
