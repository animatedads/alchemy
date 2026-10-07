/* MessagingPresence.cls
 * ooRexx Messaging & Presence v0.1-dev1
 *
 * Semantic application-facing messaging and presence objects.
 * Protocols are providers.  XMPP is one provider, never the public model.
 */

::class MessagingPresenceBuild public
::constant VERSION "0.1-dev1"
::constant MESSAGING_API "messaging/0.1"
::constant PRESENCE_API "presence/0.1"
::constant PROVIDER_API "messaging.presence.provider/0.1"

::class MessagingPresenceCapability public
::constant SEND_MESSAGE "SEND_MESSAGE"
::constant RECEIVE_MESSAGE "RECEIVE_MESSAGE"
::constant PUBLISH_PRESENCE "PUBLISH_PRESENCE"
::constant CHECK_PRESENCE "CHECK_PRESENCE"
::constant SUBSCRIBE_PRESENCE "SUBSCRIBE_PRESENCE"
::constant UNSUBSCRIBE_PRESENCE "UNSUBSCRIBE_PRESENCE"

::class MessagingPresenceCapabilities public
::method init
  expose values
  use strict arg capabilities=.nil
  values=.directory~new
  if capabilities<>.nil then do c over capabilities
    self~add(c)
  end
::method add
  expose values
  use strict arg capability
  key=translate(strip(capability))
  if key="" then raise syntax 88.900 array("capability must not be empty")
  values[key]=.true
  return self
::method remove
  expose values
  use strict arg capability
  values~remove(translate(strip(capability)))
  return self
::method supports
  expose values
  use strict arg capability
  return values~hasIndex(translate(strip(capability)))
::method all
  expose values
  out=.array~new
  do c over .MessagingPresenceCapabilities~orderedNames
    if values~hasIndex(c) then out~append(c)
  end
  return out
::method signature
  expose values
  out=""
  do c over .MessagingPresenceCapabilities~orderedNames
    if values~hasIndex(c) then do
      if out<>"" then out=out||"," 
      out=out||c
    end
  end
  return out
::method orderedNames class
  return .array~of(.MessagingPresenceCapability~SEND_MESSAGE, .MessagingPresenceCapability~RECEIVE_MESSAGE, -
      .MessagingPresenceCapability~PUBLISH_PRESENCE, .MessagingPresenceCapability~CHECK_PRESENCE, -
      .MessagingPresenceCapability~SUBSCRIBE_PRESENCE, .MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE)

::class MessagingAddress public
::method init
  expose localId authority endpoint metadata
  use strict arg localId, authority="", endpoint="", metadata=.nil
  localId=strip(localId)
  authority=strip(authority)
  endpoint=strip(endpoint)
  if localId="" then raise syntax 88.900 array("messaging address localId must not be empty")
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute localId get
::attribute authority get
::attribute endpoint get
::attribute metadata get
::method sameIdentity
  expose localId authority endpoint
  use strict arg other
  if other=.nil then return .false
  return localId==other~localId & authority==other~authority & endpoint==other~endpoint

::class Message public
::method init
  expose messageId fromAddress toAddress body subject contentType threadId createdAt replyTo metadata
  use strict arg messageId, fromAddress, toAddress, body, subject="", contentType="text/plain", threadId="", createdAt="", replyTo=.nil, metadata=.nil
  messageId=strip(messageId)
  if messageId="" then raise syntax 88.900 array("messageId must not be empty")
  if fromAddress=.nil | toAddress=.nil then raise syntax 88.900 array("message requires from and to address objects")
  fromAddress=fromAddress
  toAddress=toAddress
  body=body
  subject=subject
  contentType=strip(contentType)
  threadId=strip(threadId)
  createdAt=strip(createdAt)
  replyTo=replyTo
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute messageId get
::attribute fromAddress get
::attribute toAddress get
::attribute body get
::attribute subject get
::attribute contentType get
::attribute threadId get
::attribute createdAt get
::attribute replyTo get
::attribute metadata get
::method reply
  expose fromAddress toAddress threadId
  use strict arg newMessageId, body, createdAt="", metadata=.nil
  return .Message~new(newMessageId,toAddress,fromAddress,body,"","text/plain",threadId,createdAt,self,metadata)

::class PresenceAvailability public
::constant AVAILABLE "AVAILABLE"
::constant UNAVAILABLE "UNAVAILABLE"
::constant AWAY "AWAY"
::constant BUSY "BUSY"

::class PresenceState public
::method init
  expose address availability statusText observedAt source metadata
  use strict arg address, availability, statusText="", observedAt="", source="", metadata=.nil
  if address=.nil then raise syntax 88.900 array("presence state requires address")
  availability=translate(strip(availability))
  if availability<>.PresenceAvailability~AVAILABLE & availability<>.PresenceAvailability~UNAVAILABLE & -
     availability<>.PresenceAvailability~AWAY & availability<>.PresenceAvailability~BUSY then -
       raise syntax 88.900 array("unsupported presence availability")
  address=address
  statusText=statusText
  observedAt=strip(observedAt)
  source=strip(source)
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute address get
::attribute availability get
::attribute statusText get
::attribute observedAt get
::attribute source get
::attribute metadata get

::class PresenceSubscriptionState public
::constant REQUESTED "REQUESTED"
::constant APPROVED "APPROVED"
::constant REVOKED "REVOKED"

::class PresenceSubscription public
::method init
  expose observer subject state metadata
  use strict arg observer, subject, state="", metadata=.nil
  if observer=.nil | subject=.nil then raise syntax 88.900 array("presence subscription requires observer and subject")
  if state="" then state=.PresenceSubscriptionState~REQUESTED
  state=translate(strip(state))
  observer=observer
  subject=subject
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute observer get
::attribute subject get
::attribute state get
::attribute metadata get

::class MessagingDeliveryStatus public
::constant SENT "SENT"
::constant UNAVAILABLE "UNAVAILABLE"
::constant FAILED "FAILED"

::class MessagingDeliveryResult public
::method init
  expose status message providerId evidence
  use strict arg status, message, providerId="", evidence=""
  status=translate(strip(status))
  message=message
  providerId=strip(providerId)
  evidence=evidence
::attribute status get
::attribute message get
::attribute providerId get
::attribute evidence get
::method sent
  expose status
  return status=.MessagingDeliveryStatus~SENT

/* A provider offer is a fresh observation.  It is not registration authority
 * and it must not be cached as permanent truth by the caller. */
::class MessagingPresenceOffer public
::method init
  expose provider capabilities priority available scope evidence
  use strict arg provider, capabilities, priority=100, available=.true, scope="", evidence=""
  if provider=.nil | capabilities=.nil then raise syntax 88.900 array("provider offer requires provider and capabilities")
  provider=provider
  capabilities=capabilities
  priority=priority+0
  available=available
  scope=strip(scope)
  evidence=evidence
::attribute provider get
::attribute capabilities get
::attribute priority get
::attribute available get
::attribute scope get
::attribute evidence get
::method providerId
  expose provider
  return provider~providerId
::method supports
  expose capabilities available
  use strict arg capability
  return available & capabilities~supports(capability)
::method signature
  expose capabilities priority available scope
  return self~providerId||":"||capabilities~signature||":"||priority||":"||available||":"||scope

::class MessagingPresenceProvider public
::method providerId abstract
::method offers abstract
::method canRoute
  use strict arg address, capability, context=.nil
  return .true
::method send
  use strict arg message, context=.nil
  return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~FAILED,message,self~providerId,"send not implemented")
::method receive
  use strict arg context=.nil
  return .nil
::method publishPresence
  use strict arg state, context=.nil
  return .false
::method presence
  use strict arg address, context=.nil
  return .nil
::method subscribePresence
  use strict arg address, context=.nil
  return .false
::method unsubscribePresence
  use strict arg address, context=.nil
  return .false

::class MessagingPresenceProviderRegistry public
::method init
  expose providers order revision
  providers=.directory~new
  order=.array~new
  revision=0
::attribute revision get
::method register
  expose providers order revision
  use strict arg provider
  if provider=.nil then raise syntax 88.900 array("provider must not be NIL")
  id=strip(provider~providerId)
  if id="" then raise syntax 88.900 array("providerId must not be empty")
  if \providers~hasIndex(id) then order~append(id)
  providers[id]=provider
  revision+=1
  return self
::method unregister
  expose providers revision
  use strict arg providerId
  id=strip(providerId)
  if \providers~hasIndex(id) then return .false
  providers~remove(id)
  revision+=1
  return .true
::method provider
  expose providers
  use strict arg providerId
  return providers[strip(providerId)]
::method registeredProviders
  expose providers order
  out=.array~new
  do id over order
    if providers~hasIndex(id) then out~append(providers[id])
  end
  return out
::method discover
  use strict arg context=.nil
  out=.array~new
  do provider over self~registeredProviders
    offers=provider~offers(context)
    if offers=.nil then iterate
    if offers~isA(.Array) then do
      do offer over offers
        if offer<>.nil & offer~available then out~append(offer)
      end
    end
    else if offers~available then out~append(offers)
  end
  return out
::method offersSupporting
  use strict arg capability, address=.nil, context=.nil
  out=.array~new
  do offer over self~discover(context)
    if \offer~supports(capability) then iterate
    if address<>.nil then do
      if \offer~provider~canRoute(address,capability,context) then iterate
    end
    out~append(offer)
  end
  return out
::method select
  use strict arg capability, address=.nil, context=.nil
  best=.nil
  do offer over self~offersSupporting(capability,address,context)
    if best=.nil then best=offer
    else if offer~priority<best~priority then best=offer
    else if offer~priority=best~priority then do
      if offer~providerId<best~providerId then best=offer
    end
  end
  return best
::method surfaceSignature
  expose revision
  use strict arg context=.nil
  out="r"||revision
  do offer over self~discover(context)
    out=out||"|"||offer~signature
  end
  return out

::class Messaging public
::method init
  expose registry
  use strict arg registry
  if registry=.nil then raise syntax 88.900 array("Messaging requires provider registry")
  registry=registry
::attribute registry get
::method send
  expose registry
  use strict arg message, context=.nil
  offer=registry~select(.MessagingPresenceCapability~SEND_MESSAGE,message~toAddress,context)
  if offer=.nil then return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~UNAVAILABLE,message,"","no current messaging provider can route message")
  return offer~provider~send(message,context)
::method receive
  expose registry
  use strict arg context=.nil
  offer=registry~select(.MessagingPresenceCapability~RECEIVE_MESSAGE,.nil,context)
  if offer=.nil then return .nil
  return offer~provider~receive(context)
::method providers
  expose registry
  use strict arg context=.nil
  return registry~discover(context)

::class Presence public
::method init
  expose registry
  use strict arg registry
  if registry=.nil then raise syntax 88.900 array("Presence requires provider registry")
  registry=registry
::attribute registry get
::method publish
  expose registry
  use strict arg state, context=.nil
  offer=registry~select(.MessagingPresenceCapability~PUBLISH_PRESENCE,state~address,context)
  if offer=.nil then return .false
  return offer~provider~publishPresence(state,context)
::method current
  expose registry
  use strict arg address, context=.nil
  offer=registry~select(.MessagingPresenceCapability~CHECK_PRESENCE,address,context)
  if offer=.nil then return .nil
  return offer~provider~presence(address,context)
::method subscribe
  expose registry
  use strict arg address, context=.nil
  offer=registry~select(.MessagingPresenceCapability~SUBSCRIBE_PRESENCE,address,context)
  if offer=.nil then return .false
  return offer~provider~subscribePresence(address,context)
::method unsubscribe
  expose registry
  use strict arg address, context=.nil
  offer=registry~select(.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE,address,context)
  if offer=.nil then return .false
  return offer~provider~unsubscribePresence(address,context)
