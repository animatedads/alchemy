/* InstrumentationRelationshipAdapters.cls
 * Read-only adapters from domain-owned relationship/topology surfaces into
 * instrumentation.relationship-set/1 observations.
 *
 * Instrumentation does not infer topology.  Each adapter names the authority
 * whose complete current scope is being projected.  Consumers may compare
 * retained sets over time, but mutation and relationship meaning remain with
 * the named domain authority.
 */

::class InstrumentationRelationshipAdapterBuild public
::constant VERSION "0.1-dev6"
::constant API "instrumentation.mesh/0.1"

::class InstrumentationRelationshipSupport public

/* Build one stable relationship id from scope-local identity parts. */
::method id class
  use strict arg prefix,left,right
  return prefix~string||":"||left~string||":"||right~string

/* Queue manager references are explicit semantic projections, not network
 * endpoints.  The caller may supply a different prefix for its estate. */
::method queueManagerRef class
  use strict arg managerId,prefix="queue-manager://"
  return prefix~string||managerId~string

/* ---------------------------------------------------------------------- */
/* Current Queue Channel relationships. Queue Fabric remains channel/routing
 * authority; this source only describes presently configured sender/receiver
 * edges and their observed channel state. */
::class QueueChannelRelationshipSource public
::method init
  expose localManagerRef channels remoteRefPrefix
  use strict arg localManagerRefArg,channelsArg,remoteRefPrefixArg="queue-manager://"
  localManagerRef=localManagerRefArg~string~strip
  channels=channelsArg
  remoteRefPrefix=remoteRefPrefixArg~string
  if localManagerRef="" | channels==.nil then raise syntax 88.900 array("queue relationship source requires local manager ref and channel fabric")

::method relationshipSet
  expose localManagerRef channels remoteRefPrefix
  use strict arg observedAt=""
  relationships=.array~new
  do channel over channels~senderChannels
    remoteRef=.InstrumentationRelationshipSupport~queueManagerRef(channel~remoteManager,remoteRefPrefix)
    dims=.directory~new
    dims["channel"]=channel~channelName
    dims["direction"]="SEND"
    dims["state"]=channel~state
    relationships~append(.InstrumentationCodec~relationship(.InstrumentationRelationshipSupport~id("queue-send",localManagerRef,channel~channelName),"QUEUE_TRAFFIC_TO",localManagerRef,remoteRef,"QUEUE_FABRIC",observedAt,"PRESENT",.nil,dims))
  end
  do channel over channels~receiverChannels
    sourceRef=.InstrumentationRelationshipSupport~queueManagerRef(channel~sourceManager,remoteRefPrefix)
    dims=.directory~new
    dims["channel"]=channel~channelName
    dims["direction"]="RECEIVE"
    dims["state"]=channel~state
    relationships~append(.InstrumentationCodec~relationship(.InstrumentationRelationshipSupport~id("queue-receive",sourceRef,channel~channelName),"QUEUE_TRAFFIC_TO",sourceRef,localManagerRef,"QUEUE_FABRIC",observedAt,"PRESENT",.nil,dims))
  end
  return .InstrumentationCodec~relationshipSet(localManagerRef||"/channels","QUEUE_FABRIC",.true,relationships,observedAt)

/* ---------------------------------------------------------------------- */
/* RexxOS estate membership.  RTO2 Grid owns current MU/MI membership, but it
 * explicitly does not own workload placement or ACTIVE/SPARE selection.  This
 * adapter therefore publishes HAS_MANAGEMENT_UNIT / HAS_MESH_INSTANCE only. */
::class RexxOSGridRelationshipSource public
::method init
  expose controller
  use strict arg controllerArg
  if controllerArg==.nil then raise syntax 88.900 array("RexxOS relationship source requires estate controller")
  controller=controllerArg

::method relationshipSet
  expose controller
  use strict arg observedAt=""
  estate=controller~estateSnapshot
  gridId=estate["grid_id"]~string
  gridRef="rexxos://"||gridId||"/estate"
  relationships=.array~new
  do member over controller~estateMembers
    dims=.directory~new
    dims["member_kind"]=member~memberKind
    dims["membership_state"]=member~membershipState
    dims["incarnation"]=member~incarnation
    dims["management_unit_id"]=member~managementUnitId
    if member~memberKind="MU" then do
      relationshipId=.InstrumentationRelationshipSupport~id("rto-mu",gridId,member~memberId)
      relationships~append(.InstrumentationCodec~relationship(relationshipId,"HAS_MANAGEMENT_UNIT",gridRef,member~semanticRef,"REXXOS_GRID",observedAt,"PRESENT",.nil,dims))
    end
    else do
      muRef="rexxos://"||gridId||"/mu/"||member~managementUnitId
      relationshipId=.InstrumentationRelationshipSupport~id("rto-mi",member~managementUnitId,member~memberId)
      relationships~append(.InstrumentationCodec~relationship(relationshipId,"HAS_MESH_INSTANCE",muRef,member~semanticRef,"REXXOS_GRID",observedAt,"PRESENT",.nil,dims))
    end
  end
  return .InstrumentationCodec~relationshipSet(gridRef||"/membership","REXXOS_GRID",.true,relationships,observedAt)

/* ---------------------------------------------------------------------- */
/* LDAP/identity failover exposes the currently fenced holder for a logical
 * peer epoch.  Promotion policy remains external; this adapter only reports
 * the holder already accepted by IdentityPeerEpochAuthority. */
::class IdentityPeerAuthorityRelationshipSource public
::method init
  expose epochAuthority peerIds logicalPrefix holderPrefix
  use strict arg epochAuthorityArg,peerIdsArg,logicalPrefixArg="identity-peer://",holderPrefixArg="runtime://"
  if epochAuthorityArg==.nil | peerIdsArg==.nil then raise syntax 88.900 array("identity authority relationship source requires epoch authority and peer ids")
  epochAuthority=epochAuthorityArg
  peerIds=peerIdsArg
  logicalPrefix=logicalPrefixArg~string
  holderPrefix=holderPrefixArg~string

::method relationshipSet
  expose epochAuthority peerIds logicalPrefix holderPrefix
  use strict arg observedAt=""
  relationships=.array~new
  do peerId over peerIds
    peer=peerId~string
    epoch=epochAuthority~current(peer)
    holder=epochAuthority~currentHolder(peer)
    if epoch=.nil | holder=.nil | holder~string="" then iterate
    dims=.directory~new
    dims["epoch"]=epoch
    relationships~append(.InstrumentationCodec~relationship("identity-holder:"||peer,"AUTHORITY_HELD_BY",logicalPrefix||peer,holderPrefix||holder~string,"IDENTITY_PEER_EPOCH_AUTHORITY",observedAt,"PRESENT",.nil,dims))
  end
  return .InstrumentationCodec~relationshipSet("identity-peer://authority-holders","IDENTITY_PEER_EPOCH_AUTHORITY",.true,relationships,observedAt)

/* ---------------------------------------------------------------------- */
/* Generic bridge from Management Relationship Discovery.  Endpoints are
 * original domain objects, so an explicit resolver is mandatory.  The bridge
 * never falls back to object~string because that would fabricate persistent
 * identity from presentation text. */
::class ManagementRelationshipInstrumentationSource public
::method init
  expose sourceId provider resolver context
  use strict arg sourceIdArg,providerArg,resolverArg,contextArg=.nil
  sourceId=sourceIdArg~string~strip
  provider=providerArg; resolver=resolverArg; context=contextArg
  if sourceId="" | provider==.nil | resolver==.nil then raise syntax 88.900 array("management relationship instrumentation requires source id, provider and resolver")
  if \resolver~hasMethod("SEMANTICREF") then raise syntax 88.900 array("management relationship resolver must expose semanticRef(object)")

::method relationshipSet
  expose sourceId provider resolver context
  use strict arg observedAt=""
  discovered=provider~discoverRelationships(context)
  if discovered==.nil | \discovered~isA(.Array) then raise syntax 88.900 array("management relationship provider must return an Array")
  relationships=.array~new
  do relation over discovered
    fromRef=resolver~semanticRef(relation~fromObject)
    toRef=resolver~semanticRef(relation~toObject)
    if fromRef==.nil | toRef==.nil | fromRef~string~strip="" | toRef~string~strip="" then raise syntax 88.900 array("management relationship endpoint has no semantic ref: "||relation~id)
    evidence=.nil
    if resolver~hasMethod("EVIDENCEPROJECTION") then evidence=resolver~evidenceProjection(relation~evidence)
    dims=.directory~new
    dims["management_source_id"]=sourceId
    relationshipAuthority=relation~authority~string~strip
    if relationshipAuthority="" then relationshipAuthority="MANAGEMENT_RELATIONSHIP_SOURCE:"||sourceId
    relationships~append(.InstrumentationCodec~relationship(sourceId||":"||relation~id,relation~kind,fromRef,toRef,relationshipAuthority,observedAt,"PRESENT",evidence,dims))
  end
  return .InstrumentationCodec~relationshipSet("management://relationships/"||sourceId,"MANAGEMENT_RELATIONSHIP_SOURCE:"||sourceId,.true,relationships,observedAt)

::requires "InstrumentationMesh.cls"
