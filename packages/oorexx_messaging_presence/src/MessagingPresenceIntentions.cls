/* MessagingPresenceIntentions.cls
 * Dynamic Intention surface for Messaging & Presence.
 *
 * Canonical registrations are intentionally non-natural tokens.  Natural
 * user-facing meaning is proposed only by a currently discovered capability
 * surface, so a vanished provider cannot remain available through a stale
 * static phrase catalogue.
 */

::class MessagingPresenceIntentionBuild public
::constant VERSION "0.1-dev1"
::constant API "messaging.presence.intention.discovery/0.1"

::class MessagingPresenceIntentionId public
::constant SEND "MP__SEND"
::constant CHECK_PRESENCE "MP__CHECK_PRESENCE"
::constant PUBLISH_PRESENCE "MP__PUBLISH_PRESENCE"
::constant SUBSCRIBE_PRESENCE "MP__SUBSCRIBE_PRESENCE"
::constant UNSUBSCRIBE_PRESENCE "MP__UNSUBSCRIBE_PRESENCE"

::class MessagingPresenceIntentionInstaller public
::method install class
  use strict arg service, registry, bucketName="MESSAGING_PRESENCE"
  if service~bucket(bucketName)=.nil then service~registerBucket(bucketName,.IntentionBucketPolicy~new("FLEXIBLE",50,8,.false,.false))
  self~ensure(service,.MessagingPresenceIntentionId~SEND,"SEND_MESSAGE",bucketName)
  self~ensure(service,.MessagingPresenceIntentionId~CHECK_PRESENCE,"CHECK_PRESENCE",bucketName)
  self~ensure(service,.MessagingPresenceIntentionId~PUBLISH_PRESENCE,"PUBLISH_PRESENCE",bucketName)
  self~ensure(service,.MessagingPresenceIntentionId~SUBSCRIBE_PRESENCE,"SUBSCRIBE_PRESENCE",bucketName)
  self~ensure(service,.MessagingPresenceIntentionId~UNSUBSCRIBE_PRESENCE,"UNSUBSCRIBE_PRESENCE",bucketName)
  service~registerDiscoveryProvider(.MessagingPresenceIntentionDiscoveryProvider~new(registry))
  return service
::method ensure class private
  use strict arg service, phrase, event, bucketName
  if service~registration(phrase)<>.nil then return service~registration(phrase)
  r=service~register(phrase,event,bucketName)
  r~tag("DOMAIN","MESSAGING_PRESENCE")
  r~tag("DYNAMIC_SURFACE",.true)
  return r

::class MessagingPresenceIntentionDiscoveryProvider public
::method init
  expose registry
  use strict arg registry
  if registry=.nil then raise syntax 88.900 array("Messaging/Presence intention discovery requires registry")
  registry=registry
::method discover
  expose registry
  use strict arg service
  signature=registry~surfaceSignature(service)
  snapshot=.IntentionDiscoverySnapshot~new("MESSAGING_PRESENCE",signature)
  offers=registry~discover(service)
  if offers~items=0 then return snapshot
  capabilities=.MessagingPresenceCapabilities~new
  do offer over offers
    do c over offer~capabilities~all
      capabilities~add(c)
    end
    fact=.IntentionEvidenceFact~new("MESSAGING_PRESENCE","PROVIDER_CAPABILITIES",offer~signature,100,offer~providerId,"OBSERVED",signature)
    snapshot~addEvidenceFact(fact)
  end
  provider=.MessagingPresenceSurfaceProvider~new(capabilities,signature)
  ad=.IntentionSurfaceAdvertisement~new("MESSAGING_PRESENCE",provider,"MESSAGING_PRESENCE","PROVIDES","SESSION","DISCOVERY","OBSERVED")
  snapshot~addSurfaceAdvertisement(ad)
  return snapshot

::class MessagingPresenceSurfaceProvider public
::method init
  expose capabilities signature
  use strict arg capabilities, signature
  capabilities=capabilities
  signature=signature
::method propose
  expose capabilities signature
  use strict arg service, text
  t=translate(space(text))
  if capabilities~supports(.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE) then do
    if self~has(t,"UNSUBSCRIBE") | self~hasPhrase(t,"STOP PRESENCE UPDATES") then return self~proposal(.MessagingPresenceIntentionId~UNSUBSCRIBE_PRESENCE,96,signature)
  end
  if capabilities~supports(.MessagingPresenceCapability~SUBSCRIBE_PRESENCE) then do
    if self~has(t,"SUBSCRIBE") & self~has(t,"PRESENCE") then return self~proposal(.MessagingPresenceIntentionId~SUBSCRIBE_PRESENCE,96,signature)
    if self~hasPhrase(t,"PRESENCE UPDATES") then return self~proposal(.MessagingPresenceIntentionId~SUBSCRIBE_PRESENCE,90,signature)
  end
  if capabilities~supports(.MessagingPresenceCapability~PUBLISH_PRESENCE) then do
    if self~hasPhrase(t,"SET MY PRESENCE") | self~hasPhrase(t,"PUBLISH MY PRESENCE") | self~hasPhrase(t,"I AM AVAILABLE") | self~hasPhrase(t,"I AM AWAY") | self~hasPhrase(t,"I AM BUSY") then -
      return self~proposal(.MessagingPresenceIntentionId~PUBLISH_PRESENCE,96,signature)
  end
  if capabilities~supports(.MessagingPresenceCapability~CHECK_PRESENCE) then do
    if self~has(t,"PRESENCE") | self~has(t,"AVAILABLE") | self~has(t,"ONLINE") then return self~proposal(.MessagingPresenceIntentionId~CHECK_PRESENCE,90,signature)
  end
  if capabilities~supports(.MessagingPresenceCapability~SEND_MESSAGE) then do
    if self~has(t,"MESSAGE") & (self~has(t,"SEND") | self~has(t,"TELL") | self~has(t,"NOTIFY")) then return self~proposal(.MessagingPresenceIntentionId~SEND,94,signature)
    if left(t,5)="TELL " then return self~proposal(.MessagingPresenceIntentionId~SEND,88,signature)
  end
  return .array~new
::method proposal private
  use strict arg id, score, signature
  return .array~of(.IntentionProposal~new(id,score,"MESSAGING_PRESENCE_SURFACE",.true,"live capability "||signature))
::method has private
  use strict arg text, word
  return wordpos(word,text)>0
::method hasPhrase private
  use strict arg text, phrase
  return pos(phrase,text)>0

::requires "MessagingPresence.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
