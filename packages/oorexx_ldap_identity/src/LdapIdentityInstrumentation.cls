/* LdapIdentityInstrumentation.cls - Instrumentation Mesh adapter v0.1-dev18.
 * Observation only: metrics and events never confer directory, LDAP,
 * replication or failover authority and never contain credentials or entry
 * attribute values.  Correlation is explicit producer evidence only.
 */
::class LdapIdentityInstrumentationBuild public
::constant API_VERSION "identity.instrumentation/0.1"
::constant MESH_API "instrumentation.mesh/0.1"
::constant CORRELATION_API "instrumentation.correlation/0.1"
::constant EVENT_AUTHORITY "LDAP_IDENTITY_REPLICATION"

::class LdapIdentityInstrumentationSource public
::method init
  expose emitter dimensions eventObserver
  use strict arg identity, dimensionsArg=.nil
  dimensions=.InstrumentationCodec~copyDirectory(dimensionsArg)
  emitter=.InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  eventObserver=.InstrumentationEventObserver~new(identity,.LdapIdentityInstrumentationBuild~EVENT_AUTHORITY)

::method peerRequestAccepted
  expose emitter eventObserver
  use strict arg request
  dims=self~peerDims(request)
  emitter~requestAccepted
  emitter~counterAdd("identity.replication.requests.accepted_total",1,"count",dims)
  refs=self~requestContextRefs(request)
  ignore=eventObserver~record(self~requestEventId(request),"IDENTITY_REPLICATION_REQUEST_ACCEPTED",.InstrumentationEventSeverity~INFO,"",request~requestId,"",request~requestId,"peer replication request accepted",.array~new,refs,.nil,dims)
  return self

::method peerAck
  expose emitter eventObserver
  use strict arg request, ack
  dims=self~peerDims(request)
  dims["peer_id"]=ack~peerId
  dims["status"]=ack~status
  emitter~counterAdd("identity.replication.acks.total",1,"count",dims)
  if ack~ok then do
    emitter~counterAdd("identity.replication.acks.success_total",1,"count",dims)
    severity=.InstrumentationEventSeverity~INFO
  end
  else do
    emitter~counterAdd("identity.replication.acks.rejected_total",1,"count",dims)
    severity=.InstrumentationEventSeverity~WARNING
  end
  refs=self~requestContextRefs(request)
  refs~append("identity-peer:"||ack~peerId)
  evidence=.directory~new
  evidence["status"]=ack~status
  evidence["durable_revision"]=ack~durableRevision
  eventId="identity.peer.ack:"||request~requestId||":"||ack~peerId||":"||ack~status||":"||ack~durableRevision
  ignore=eventObserver~record(eventId,"IDENTITY_REPLICATION_ACK",severity,"",request~requestId,self~requestEventId(request),request~requestId,"peer application acknowledgement",.array~new,refs,evidence,dims)
  return self

::method peerCommit
  expose emitter eventObserver
  use strict arg request, state
  dims=self~peerDims(request)
  dims["commit_state"]=state~string
  emitter~requestCompleted
  emitter~counterAdd("identity.replication.commits.total",1,"count",dims)
  evidence=.directory~new
  evidence["commit_state"]=state~string
  ignore=eventObserver~record("identity.peer.commit:"||request~requestId,"IDENTITY_REPLICATION_COMMITTED",.InstrumentationEventSeverity~INFO,"",request~requestId,self~requestEventId(request),request~requestId,"peer replication commit policy satisfied",.array~new,self~requestContextRefs(request),evidence,dims)
  return self

::method peerPending
  expose emitter eventObserver
  use strict arg request, good, required
  dims=self~peerDims(request)
  emitter~requestFailed
  emitter~counterAdd("identity.replication.pending_total",1,"count",dims)
  emitter~gaugeSet("identity.replication.last_ack_count",good,"acks",dims)
  emitter~gaugeSet("identity.replication.last_required_ack_count",required,"acks",dims)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  evidence=.directory~new
  evidence["ack_count"]=good
  evidence["required_ack_count"]=required
  ignore=eventObserver~record("identity.peer.pending:"||request~requestId,"IDENTITY_REPLICATION_PENDING",.InstrumentationEventSeverity~WARNING,"",request~requestId,self~requestEventId(request),request~requestId,"peer replication remains below commit threshold",.array~new,self~requestContextRefs(request),evidence,dims)
  return self

::method peerRetry
  expose emitter eventObserver
  use strict arg request, pendingCount
  dims=self~peerDims(request)
  emitter~counterAdd("identity.replication.retries_total",1,"count",dims)
  emitter~gaugeSet("identity.replication.last_retry_targets",pendingCount,"peers",dims)
  evidence=.directory~new
  evidence["pending_targets"]=pendingCount
  eventId="identity.peer.retry:"||request~requestId||":"||pendingCount
  ignore=eventObserver~record(eventId,"IDENTITY_REPLICATION_RETRY",.InstrumentationEventSeverity~NOTICE,"",request~requestId,self~requestEventId(request),request~requestId,"targeted replication retry",.array~new,self~requestContextRefs(request),evidence,dims)
  return self

::method authorityPromotion
  expose emitter dimensions eventObserver
  use strict arg logicalPeerId, oldEpoch, newEpoch, oldHolder, newHolder
  dims=.InstrumentationCodec~copyDirectory(dimensions)
  dims["logical_peer_id"]=logicalPeerId~string
  dims["old_holder"]=oldHolder~string
  dims["new_holder"]=newHolder~string
  emitter~counterAdd("identity.failover.promotions_total",1,"count",dims)
  emitter~gaugeSet("identity.failover.current_epoch",newEpoch,"epoch",dims)
  correlationId="identity-failover:"||logicalPeerId~string||":"||newEpoch
  refs=.array~new
  refs~append("identity-logical-peer:"||logicalPeerId~string)
  refs~append("identity-holder:"||oldHolder~string)
  refs~append("identity-holder:"||newHolder~string)
  evidence=.directory~new
  evidence["old_epoch"]=oldEpoch
  evidence["new_epoch"]=newEpoch
  evidence["old_holder"]=oldHolder~string
  evidence["new_holder"]=newHolder~string
  ignore=eventObserver~record("identity.failover.promotion:"||logicalPeerId~string||":"||newEpoch,"IDENTITY_AUTHORITY_PROMOTED",.InstrumentationEventSeverity~NOTICE,"",correlationId,"",correlationId,"identity authority holder promoted",.array~new,refs,evidence,dims)
  return self

::method healthy
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  return self

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::method events
  expose eventObserver
  use strict arg observedAt=""
  return eventObserver~events(observedAt)

::method requestEventId private
  use strict arg request
  return "identity.peer.request:"||request~requestId||":accepted"

::method requestContextRefs private
  use strict arg request
  refs=.array~new
  refs~append("identity-request:"||request~requestId)
  refs~append("identity-change:"||request~change~semanticIdentity)
  refs~append("identity-logical-peer:"||request~originPeerId)
  refs~append("identity-holder:"||request~authorityHolderId)
  return refs

::method peerDims private
  expose dimensions
  use strict arg request
  dims=.InstrumentationCodec~copyDirectory(dimensions)
  dims["logical_peer_id"]=request~originPeerId
  dims["authority_holder_id"]=request~authorityHolderId
  dims["epoch"]=request~originEpoch
  dims["commit_policy"]=request~commitPolicy
  return dims

::requires "InstrumentationMesh.cls"
::requires "InstrumentationServiceAdapters.cls"
::requires "src/IdentityPeerFabric.cls"
