/* MessagingPresenceInstrumentation.cls
 * ooRexx Messaging & Presence v0.1-dev4
 *
 * Thin adapter onto instrumentation.mesh/0.1. The Messaging & Presence service
 * remains authoritative; Instrumentation Mesh owns envelopes/history/query.
 */
::class MessagingPresenceInstrumentationBuild public
::constant VERSION "0.1-dev4"
::constant API "messaging.presence.instrumentation/0.1"
::constant MESH_API "instrumentation.mesh/0.1"

::class MessagingPresenceMetric public
::constant MESSAGING_SEND_TOTAL "messaging.send.total"
::constant MESSAGING_RECEIVE_POLL_TOTAL "messaging.receive.poll.total"
::constant MESSAGING_RECEIVED_TOTAL "messaging.received.total"
::constant MESSAGING_DELIVERY_FAILED_TOTAL "messaging.delivery.failed.total"
::constant PRESENCE_PUBLISH_TOTAL "presence.publish.total"
::constant PRESENCE_QUERY_TOTAL "presence.query.total"
::constant PRESENCE_OBSERVED_TOTAL "presence.observed.total"
::constant PRESENCE_SUBSCRIBE_TOTAL "presence.subscribe.total"
::constant PRESENCE_UNSUBSCRIBE_TOTAL "presence.unsubscribe.total"
::constant PROVIDER_STATE "messaging.provider.state"
::constant TRANSPORT_STATE "messaging.transport.state"

::class MessagingPresenceInstrumentation public
::method init
  expose identity emitter
  use strict arg identityArg, emitterArg=.nil
  if identityArg=.nil then raise syntax 88.900 array("instrumentation identity is required")
  identity=.InstrumentationCodec~copyDirectory(identityArg)
  if emitterArg=.nil then emitter=.InstrumentationEmitter~new(identity); else emitter=emitterArg
  emitter~setHealth(.InstrumentationHealth~STARTING)
::attribute emitter get
::method identity; expose identity; return .InstrumentationCodec~copyDirectory(identity)
::method semanticRef; expose identity; return .InstrumentationCodec~semanticRef(identity)
::method setHealth; expose emitter; use strict arg health; emitter~setHealth(health); return self
::method providerState
  expose emitter
  use strict arg state, providerId=""
  dims=.directory~new
  if strip(providerId)<>"" then dims["provider_id"]=strip(providerId)
  emitter~gaugeSet(.MessagingPresenceMetric~PROVIDER_STATE,state,"state",dims,.InstrumentationMetricKind~STATE)
  return self
::method transportState
  expose emitter
  use strict arg state, providerId=""
  dims=.directory~new
  if strip(providerId)<>"" then dims["provider_id"]=strip(providerId)
  emitter~gaugeSet(.MessagingPresenceMetric~TRANSPORT_STATE,state,"state",dims,.InstrumentationMetricKind~STATE)
  return self
::method operationAccepted
  expose emitter
  use strict arg operation
  emitter~requestAccepted
  metric=self~operationMetric(operation)
  if metric<>"" then emitter~counterAdd(metric,1)
  return self
::method operationCompleted; expose emitter; use strict arg operation; emitter~requestCompleted; return self
::method operationFailed
  expose emitter
  use strict arg operation
  emitter~requestFailed
  if translate(strip(operation))=.MessagingPresenceCapability~SEND_MESSAGE then emitter~counterAdd(.MessagingPresenceMetric~MESSAGING_DELIVERY_FAILED_TOTAL,1)
  return self
::method operationRejected; expose emitter; use strict arg operation; emitter~requestRejected; return self
::method messageReceived; expose emitter; use strict arg message=.nil; emitter~counterAdd(.MessagingPresenceMetric~MESSAGING_RECEIVED_TOTAL,1); return self
::method presenceObserved; expose emitter; use strict arg state=.nil; emitter~counterAdd(.MessagingPresenceMetric~PRESENCE_OBSERVED_TOTAL,1); return self
::method bytesIn; expose emitter; use strict arg bytes; if bytes>0 then emitter~bytesIn(bytes); return self
::method bytesOut; expose emitter; use strict arg bytes; if bytes>0 then emitter~bytesOut(bytes); return self
::method snapshot; expose emitter; use strict arg observedAt=""; return emitter~snapshot(observedAt)
::method capability
  expose identity
  operations=.array~of(.MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~RECEIVE_MESSAGE,.MessagingPresenceCapability~PUBLISH_PRESENCE,.MessagingPresenceCapability~CHECK_PRESENCE,.MessagingPresenceCapability~SUBSCRIBE_PRESENCE,.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE)
  metrics=.array~of(.InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL,.InstrumentationVocabulary~REQUEST_INFLIGHT,.InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL,.InstrumentationVocabulary~REQUEST_FAILED_TOTAL,.InstrumentationVocabulary~REQUEST_REJECTED_TOTAL,.InstrumentationVocabulary~BYTES_IN_TOTAL,.InstrumentationVocabulary~BYTES_OUT_TOTAL,.MessagingPresenceMetric~MESSAGING_SEND_TOTAL,.MessagingPresenceMetric~MESSAGING_RECEIVE_POLL_TOTAL,.MessagingPresenceMetric~MESSAGING_RECEIVED_TOTAL,.MessagingPresenceMetric~MESSAGING_DELIVERY_FAILED_TOTAL,.MessagingPresenceMetric~PRESENCE_PUBLISH_TOTAL,.MessagingPresenceMetric~PRESENCE_QUERY_TOTAL,.MessagingPresenceMetric~PRESENCE_OBSERVED_TOTAL,.MessagingPresenceMetric~PRESENCE_SUBSCRIBE_TOTAL,.MessagingPresenceMetric~PRESENCE_UNSUBSCRIBE_TOTAL,.MessagingPresenceMetric~PROVIDER_STATE,.MessagingPresenceMetric~TRANSPORT_STATE)
  return .InstrumentationCodec~capability(.InstrumentationCodec~copyDirectory(identity),operations,metrics,.array~new)
::method operationMetric private
  use strict arg operation
  op=translate(strip(operation))
  select
    when op=.MessagingPresenceCapability~SEND_MESSAGE then return .MessagingPresenceMetric~MESSAGING_SEND_TOTAL
    when op=.MessagingPresenceCapability~RECEIVE_MESSAGE then return .MessagingPresenceMetric~MESSAGING_RECEIVE_POLL_TOTAL
    when op=.MessagingPresenceCapability~PUBLISH_PRESENCE then return .MessagingPresenceMetric~PRESENCE_PUBLISH_TOTAL
    when op=.MessagingPresenceCapability~CHECK_PRESENCE then return .MessagingPresenceMetric~PRESENCE_QUERY_TOTAL
    when op=.MessagingPresenceCapability~SUBSCRIBE_PRESENCE then return .MessagingPresenceMetric~PRESENCE_SUBSCRIBE_TOTAL
    when op=.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE then return .MessagingPresenceMetric~PRESENCE_UNSUBSCRIBE_TOTAL
    otherwise return ""
  end

::class InstrumentedMessagingPresenceProvider public subclass MessagingPresenceProvider
::method init
  expose delegate instrumentation
  use strict arg delegateArg, instrumentationArg
  if delegateArg=.nil | instrumentationArg=.nil then raise syntax 88.900 array("instrumented provider requires delegate and instrumentation")
  delegate=delegateArg; instrumentation=instrumentationArg
::attribute delegate get
::attribute instrumentation get
::method providerId; expose delegate; return delegate~providerId
::method offers
  expose delegate instrumentation
  use strict arg context=.nil
  original=delegate~offers(context); out=.array~new; available=.false
  if original<>.nil then do
    if original~isA(.Array) then do offer over original
      if offer=.nil then iterate
      out~append(.MessagingPresenceOffer~new(self,offer~capabilities,offer~priority,offer~available,offer~scope,offer~evidence))
      if offer~available then available=.true
    end
    else do
      offer=original
      out~append(.MessagingPresenceOffer~new(self,offer~capabilities,offer~priority,offer~available,offer~scope,offer~evidence))
      available=offer~available
    end
  end
  if available then instrumentation~providerState("AVAILABLE",self~providerId); else instrumentation~providerState("UNAVAILABLE",self~providerId)
  return out
::method canRoute; expose delegate; use strict arg address, capability, context=.nil; return delegate~canRoute(address,capability,context)
::method send
  expose delegate instrumentation
  use strict arg message, context=.nil
  op=.MessagingPresenceCapability~SEND_MESSAGE; instrumentation~operationAccepted(op)
  delivery=delegate~send(message,context)
  if delivery<>.nil & delivery~sent then instrumentation~operationCompleted(op); else instrumentation~operationFailed(op)
  return delivery
::method receive
  expose delegate instrumentation
  use strict arg context=.nil
  op=.MessagingPresenceCapability~RECEIVE_MESSAGE; instrumentation~operationAccepted(op)
  incoming=delegate~receive(context); instrumentation~operationCompleted(op)
  if incoming<>.nil then do
    if incoming~isA(.Message) then instrumentation~messageReceived(incoming)
    else if incoming~isA(.PresenceState) then instrumentation~presenceObserved(incoming)
  end
  return incoming
::method publishPresence
  expose delegate instrumentation
  use strict arg state, context=.nil
  op=.MessagingPresenceCapability~PUBLISH_PRESENCE; instrumentation~operationAccepted(op)
  ok=delegate~publishPresence(state,context)
  if ok then instrumentation~operationCompleted(op); else instrumentation~operationFailed(op)
  return ok
::method presence
  expose delegate instrumentation
  use strict arg address, context=.nil
  op=.MessagingPresenceCapability~CHECK_PRESENCE; instrumentation~operationAccepted(op)
  state=delegate~presence(address,context); instrumentation~operationCompleted(op)
  if state<>.nil then instrumentation~presenceObserved(state)
  return state
::method subscribePresence
  expose delegate instrumentation
  use strict arg address, context=.nil
  op=.MessagingPresenceCapability~SUBSCRIBE_PRESENCE; instrumentation~operationAccepted(op)
  ok=delegate~subscribePresence(address,context)
  if ok then instrumentation~operationCompleted(op); else instrumentation~operationFailed(op)
  return ok
::method unsubscribePresence
  expose delegate instrumentation
  use strict arg address, context=.nil
  op=.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE; instrumentation~operationAccepted(op)
  ok=delegate~unsubscribePresence(address,context)
  if ok then instrumentation~operationCompleted(op); else instrumentation~operationFailed(op)
  return ok

::class InstrumentedXmppTransport public subclass XmppTransport
::method init
  expose delegate instrumentation providerId
  use strict arg delegateArg, instrumentationArg, providerIdArg="xmpp"
  if delegateArg=.nil | instrumentationArg=.nil then raise syntax 88.900 array("instrumented XMPP transport requires delegate and instrumentation")
  delegate=delegateArg; instrumentation=instrumentationArg; providerId=strip(providerIdArg)
::method open
  expose delegate instrumentation providerId
  use strict arg context=.nil
  ok=delegate~open(context)
  if ok then instrumentation~transportState("OPEN",providerId); else instrumentation~transportState("OPEN_FAILED",providerId)
  return ok
::method write
  expose delegate instrumentation
  use strict arg bytes, context=.nil
  n=delegate~write(bytes,context)
  if n>0 then instrumentation~bytesOut(n)
  return n
::method read
  expose delegate instrumentation
  use strict arg maximumBytes, context=.nil
  bytes=delegate~read(maximumBytes,context)
  if bytes<>.nil then if length(bytes)>0 then instrumentation~bytesIn(length(bytes))
  return bytes
::method close
  expose delegate instrumentation providerId
  ok=delegate~close; instrumentation~transportState("CLOSED",providerId); return ok
::method secure; expose delegate; return delegate~secure
::method supportsStartTls; expose delegate; return delegate~supportsStartTls
::method startTls
  expose delegate instrumentation providerId
  use strict arg context=.nil
  ok=delegate~startTls(context)
  if ok then instrumentation~transportState("SECURE",providerId); else instrumentation~transportState("TLS_UPGRADE_FAILED",providerId)
  return ok

::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "InstrumentationMesh.cls"
