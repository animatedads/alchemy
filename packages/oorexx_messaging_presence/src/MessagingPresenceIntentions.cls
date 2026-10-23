/* MessagingPresenceIntentions.cls
 * Dynamic, executable Intention surface for Messaging & Presence.
 */
::class MessagingPresenceIntentionBuild public
::constant VERSION "0.1-dev3"
::constant API "messaging.presence.intention.discovery/0.2"

::class MessagingPresenceIntentionId public
::constant SEND "MP__SEND"
::constant CHECK_PRESENCE "MP__CHECK_PRESENCE"
::constant PUBLISH_PRESENCE "MP__PUBLISH_PRESENCE"
::constant SUBSCRIBE_PRESENCE "MP__SUBSCRIBE_PRESENCE"
::constant UNSUBSCRIBE_PRESENCE "MP__UNSUBSCRIBE_PRESENCE"

::class MessagingPresenceAddressResolver public
::method resolve abstract

::class RegisteredMessagingAddressResolver public subclass MessagingPresenceAddressResolver
::method init
  expose addresses
  addresses=.directory~new
::method register
  expose addresses
  use strict arg name, address
  key=translate(space(name))
  if key="" then raise syntax 88.900 array("messaging identity name must not be empty")
  if address=.nil then raise syntax 88.900 array("messaging identity address must not be NIL")
  addresses[key]=address
  return self
::method unregister
  expose addresses
  use strict arg name
  key=translate(space(name))
  if \addresses~hasIndex(key) then return .false
  addresses~remove(key)
  return .true
::method resolve
  expose addresses
  use strict arg name, context=.nil
  key=translate(space(name))
  if addresses~hasIndex(key) then return addresses[key]
  return .nil

::class MessagingPresenceIntentionRuntime public
::method init
  expose messaging presence addressResolver selfAddress idSequence clock
  use strict arg messaging, presence, addressResolver, selfAddress, clock=.nil
  if messaging=.nil | presence=.nil then raise syntax 88.900 array("intention runtime requires Messaging and Presence")
  if addressResolver=.nil then raise syntax 88.900 array("intention runtime requires address resolver")
  if selfAddress=.nil then raise syntax 88.900 array("intention runtime requires current MessagingAddress")
  messaging=messaging; presence=presence; addressResolver=addressResolver; selfAddress=selfAddress; idSequence=0; clock=clock
::attribute messaging get
::attribute presence get
::attribute addressResolver get
::attribute selfAddress get
::method resolveAddress
  expose addressResolver
  use strict arg value, context=.nil
  if value=.nil then return .nil
  if value~isA(.MessagingAddress) then return value
  return addressResolver~resolve(value~string,context)
::method nextMessageId
  expose idSequence
  idSequence+=1
  return "mp-"||idSequence
::method now
  expose clock
  if clock<>.nil then return clock~now
  return date("S")||"T"||time("L")

::class MessagingPresenceIntentionInstaller public
::method install class
  use strict arg service, registry, runtime, bucketName="MESSAGING_PRESENCE"
  if runtime=.nil then raise syntax 88.900 array("Messaging/Presence Intention installation requires executable runtime")
  if service~bucket(bucketName)=.nil then service~registerBucket(bucketName,.IntentionBucketPolicy~new("FLEXIBLE",50,8,.false,.false))
  self~ensureExecutable(service,.MessagingPresenceIntentionId~SEND,.MessagingPresenceSendEvent~new(runtime),bucketName,"RECIPIENT|BODY")
  self~ensureExecutable(service,.MessagingPresenceIntentionId~CHECK_PRESENCE,.MessagingPresenceCheckEvent~new(runtime),bucketName,"RECIPIENT")
  self~ensureExecutable(service,.MessagingPresenceIntentionId~PUBLISH_PRESENCE,.MessagingPresencePublishEvent~new(runtime),bucketName,"AVAILABILITY")
  self~ensureExecutable(service,.MessagingPresenceIntentionId~SUBSCRIBE_PRESENCE,.MessagingPresenceSubscribeEvent~new(runtime),bucketName,"RECIPIENT")
  self~ensureExecutable(service,.MessagingPresenceIntentionId~UNSUBSCRIBE_PRESENCE,.MessagingPresenceUnsubscribeEvent~new(runtime),bucketName,"RECIPIENT")
  service~registerDiscoveryProvider(.MessagingPresenceIntentionDiscoveryProvider~new(registry,runtime))
  return service
::method ensureExecutable class private
  use strict arg service, phrase, event, bucketName, requiredSlots=""
  if service~registration(phrase)<>.nil then return service~registration(phrase)
  r=service~register(phrase,event,bucketName)
  r~tag("DOMAIN","MESSAGING_PRESENCE"); r~tag("DYNAMIC_SURFACE",.true); r~tag("SEMANTIC_DISPATCH",.true)
  slots=changestr("|",requiredSlots," ")
  do i=1 to words(slots)
    slot=word(slots,i)
    select
      when slot="RECIPIENT" then prompt="Who should this apply to?"
      when slot="BODY" then prompt="What message should I send?"
      when slot="AVAILABILITY" then prompt="What presence should I publish: available, away, busy, or unavailable?"
      otherwise prompt="Please specify "||slot||"."
    end
    r~requireSlot(slot,prompt,.true)
  end
  return r

::class MessagingPresenceIntentionDiscoveryProvider public
::method init
  expose registry runtime
  use strict arg registry, runtime=.nil
  if registry=.nil then raise syntax 88.900 array("Messaging/Presence intention discovery requires registry")
  registry=registry; runtime=runtime
::method discover
  expose registry runtime
  use strict arg service
  signature=registry~surfaceSignature(service)
  snapshot=.IntentionDiscoverySnapshot~new("MESSAGING_PRESENCE",signature)
  offers=registry~discover(service)
  if offers~items=0 then return snapshot
  capabilities=.MessagingPresenceCapabilities~new
  do offer over offers
    do c over offer~capabilities~all; capabilities~add(c); end
    fact=.IntentionEvidenceFact~new("MESSAGING_PRESENCE","PROVIDER_CAPABILITIES",offer~signature,100,offer~providerId,"OBSERVED",signature)
    snapshot~addEvidenceFact(fact)
  end
  provider=.MessagingPresenceSurfaceProvider~new(capabilities,signature,runtime)
  snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new("MESSAGING_PRESENCE",provider,"MESSAGING_PRESENCE","PROVIDES","SESSION","DISCOVERY","OBSERVED"))
  return snapshot

::class MessagingPresenceSurfaceProvider public
::method init
  expose capabilities signature runtime
  use strict arg capabilities, signature, runtime=.nil
  capabilities=capabilities; signature=signature; runtime=runtime
::method propose
  expose capabilities signature runtime
  use strict arg service, text
  t=space(text); u=translate(t)
  if capabilities~supports(.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE) then do
    if pos("STOP PRESENCE UPDATES",u)>0 | (wordpos("UNSUBSCRIBE",u)>0 & wordpos("PRESENCE",u)>0) then do
      recipient=self~recipientAfter(u,t,"FOR"); if recipient="" then recipient=self~recipientAfter(u,t,"FROM")
      p=self~proposal(.MessagingPresenceIntentionId~UNSUBSCRIBE_PRESENCE,96,signature,"Stop presence observation")
      if recipient<>"" then p~putSlot("RECIPIENT",recipient,.true)
      return .array~of(p)
    end
  end
  if capabilities~supports(.MessagingPresenceCapability~SUBSCRIBE_PRESENCE) then do
    if (wordpos("SUBSCRIBE",u)>0 & wordpos("PRESENCE",u)>0) | pos("PRESENCE UPDATES",u)>0 then do
      recipient=self~recipientAfter(u,t,"TO"); if recipient="" then recipient=self~recipientBefore(u,t,"PRESENCE")
      p=self~proposal(.MessagingPresenceIntentionId~SUBSCRIBE_PRESENCE,96,signature,"Subscribe to presence")
      if recipient<>"" then p~putSlot("RECIPIENT",recipient,.true)
      return .array~of(p)
    end
  end
  if capabilities~supports(.MessagingPresenceCapability~PUBLISH_PRESENCE) then do
    availability=self~availability(u)
    if pos("SET MY PRESENCE",u)>0 | pos("PUBLISH MY PRESENCE",u)>0 | pos("I AM AVAILABLE",u)>0 | pos("I AM AWAY",u)>0 | pos("I AM BUSY",u)>0 | pos("I AM UNAVAILABLE",u)>0 then do
      p=self~proposal(.MessagingPresenceIntentionId~PUBLISH_PRESENCE,96,signature,"Publish semantic presence")
      if availability<>"" then p~putSlot("AVAILABILITY",availability,.true)
      status=self~statusText(t); if status<>"" then p~putSlot("STATUS_TEXT",status,.true)
      return .array~of(p)
    end
  end
  if capabilities~supports(.MessagingPresenceCapability~CHECK_PRESENCE) then do
    if wordpos("PRESENCE",u)>0 | wordpos("AVAILABLE",u)>0 | wordpos("ONLINE",u)>0 then do
      recipient=self~presenceRecipient(u,t)
      p=self~proposal(.MessagingPresenceIntentionId~CHECK_PRESENCE,90,signature,"Check semantic presence")
      if recipient<>"" then p~putSlot("RECIPIENT",recipient,.true)
      return .array~of(p)
    end
  end
  if capabilities~supports(.MessagingPresenceCapability~SEND_MESSAGE) then do
    parsed=self~parseSend(t,u)
    if parsed<>.nil then do
      p=self~proposal(.MessagingPresenceIntentionId~SEND,94,signature,"Send semantic message")
      if parsed~hasIndex("RECIPIENT") then p~putSlot("RECIPIENT",parsed["RECIPIENT"],.true)
      if parsed~hasIndex("BODY") then p~putSlot("BODY",parsed["BODY"],.true)
      if parsed~hasIndex("SUBJECT") then p~putSlot("SUBJECT",parsed["SUBJECT"],.true)
      return .array~of(p)
    end
  end
  return .array~new
::method proposal private
  use strict arg id, score, signature, summary=""
  p=.IntentionProposal~new(id,score,"MESSAGING_PRESENCE_SURFACE",.true,"live capability "||signature)
  plan=.IntentionPlan~new(id,summary)
  plan~tag("DOMAIN","MESSAGING_PRESENCE"); plan~tag("CAPABILITY_SIGNATURE",signature)
  plan~addStep("SEMANTIC_OPERATION",summary,"Messaging/Presence"); p~proposedPlan(plan)
  return p
::method parseSend private
  use strict arg text, upper
  out=.directory~new; toPos=wordpos("TO",upper)
  if wordpos("MESSAGE",upper)>0 & (wordpos("SEND",upper)>0 | wordpos("NOTIFY",upper)>0) & toPos>0 then do
    recipient=word(text,toPos+1); if recipient<>"" then out["RECIPIENT"]=self~cleanToken(recipient)
    colon=pos(":",text)
    if colon>0 then body=strip(substr(text,colon+1)); else do; body=""; if words(text)>toPos+1 then body=subword(text,toPos+2); end
    if body<>"" then out["BODY"]=body
    return out
  end
  if word(upper,1)="TELL" then do
    if words(text)>=2 then out["RECIPIENT"]=self~cleanToken(word(text,2))
    if words(text)>=3 then out["BODY"]=subword(text,3)
    return out
  end
  return .nil
::method cleanToken private
  use strict arg token
  token=strip(token)
  do while length(token)>0 & pos(right(token,1),",:;.!?")>0; token=left(token,length(token)-1); end
  return token
::method presenceRecipient private
  use strict arg upper, text
  if word(upper,1)="IS" & words(text)>=2 then return self~cleanToken(word(text,2))
  r=self~recipientAfter(upper,text,"OF"); if r<>"" then return r
  r=self~recipientAfter(upper,text,"FOR"); if r<>"" then return r
  return ""
::method recipientAfter private
  use strict arg upper, text, marker
  p=wordpos(marker,upper); if p=0 | words(text)<p+1 then return ""
  return self~cleanToken(word(text,p+1))
::method recipientBefore private
  use strict arg upper, text, marker
  p=wordpos(marker,upper); if p<=1 then return ""
  return self~cleanToken(word(text,p-1))
::method availability private
  use strict arg upper
  if pos("UNAVAILABLE",upper)>0 | pos("OFFLINE",upper)>0 then return .PresenceAvailability~UNAVAILABLE
  if pos("BUSY",upper)>0 | pos("DND",upper)>0 then return .PresenceAvailability~BUSY
  if pos("AWAY",upper)>0 then return .PresenceAvailability~AWAY
  if pos("AVAILABLE",upper)>0 | pos("ONLINE",upper)>0 then return .PresenceAvailability~AVAILABLE
  return ""
::method statusText private
  use strict arg text
  p=pos(":",text); if p=0 then return ""; return strip(substr(text,p+1))

::class MessagingPresenceEventBase public
::method init
  expose runtime
  use strict arg runtime
  if runtime=.nil then raise syntax 88.900 array("messaging intention event requires runtime")
  runtime=runtime
::attribute runtime get
::method slot
  use strict arg decision, name, defaultValue=""
  s=decision~proposal~slot(name); if s=.nil then return defaultValue; return s~value
::method resolveRecipient
  use strict arg decision
  value=self~slot(decision,"RECIPIENT",""); if value="" then return .nil
  return self~runtime~resolveAddress(value,decision)

::class MessagingPresenceSendEvent public subclass MessagingPresenceEventBase
::method invoke
  use strict arg decision
  recipient=self~resolveRecipient(decision)
  if recipient=.nil then return .MessagingPresenceDispatchResult~failed("UNKNOWN_RECIPIENT","Recipient could not be resolved")
  body=self~slot(decision,"BODY","")
  if strip(body)="" then return .MessagingPresenceDispatchResult~failed("EMPTY_BODY","Message body is empty")
  rt=self~runtime
  message=.Message~new(rt~nextMessageId,rt~selfAddress,recipient,body,self~slot(decision,"SUBJECT",""),"text/plain","",rt~now)
  delivery=rt~messaging~send(message,decision)
  return .MessagingPresenceDispatchResult~new(delivery~sent,"SEND_MESSAGE",delivery,message,delivery~evidence)

::class MessagingPresenceCheckEvent public subclass MessagingPresenceEventBase
::method invoke
  use strict arg decision
  recipient=self~resolveRecipient(decision)
  if recipient=.nil then return .MessagingPresenceDispatchResult~failed("UNKNOWN_RECIPIENT","Recipient could not be resolved")
  state=self~runtime~presence~current(recipient,decision)
  if state=.nil then return .MessagingPresenceDispatchResult~failed("PRESENCE_UNAVAILABLE","No current provider returned presence")
  return .MessagingPresenceDispatchResult~new(.true,"CHECK_PRESENCE",state,recipient,"current semantic presence")

::class MessagingPresencePublishEvent public subclass MessagingPresenceEventBase
::method invoke
  use strict arg decision
  availability=translate(strip(self~slot(decision,"AVAILABILITY","")))
  if availability="" then return .MessagingPresenceDispatchResult~failed("MISSING_AVAILABILITY","No presence state supplied")
  rt=self~runtime
  state=.PresenceState~new(rt~selfAddress,availability,self~slot(decision,"STATUS_TEXT",""),rt~now,"INTENTION")
  ok=rt~presence~publish(state,decision)
  if \ok then return .MessagingPresenceDispatchResult~failed("PUBLISH_FAILED","No current provider accepted presence")
  return .MessagingPresenceDispatchResult~new(.true,"PUBLISH_PRESENCE",state,state,"presence published")

::class MessagingPresenceSubscribeEvent public subclass MessagingPresenceEventBase
::method invoke
  use strict arg decision
  recipient=self~resolveRecipient(decision)
  if recipient=.nil then return .MessagingPresenceDispatchResult~failed("UNKNOWN_RECIPIENT","Recipient could not be resolved")
  ok=self~runtime~presence~subscribe(recipient,decision)
  if \ok then return .MessagingPresenceDispatchResult~failed("SUBSCRIBE_FAILED","No current provider accepted subscription")
  return .MessagingPresenceDispatchResult~new(.true,"SUBSCRIBE_PRESENCE",recipient,recipient,"presence subscription requested")

::class MessagingPresenceUnsubscribeEvent public subclass MessagingPresenceEventBase
::method invoke
  use strict arg decision
  recipient=self~resolveRecipient(decision)
  if recipient=.nil then return .MessagingPresenceDispatchResult~failed("UNKNOWN_RECIPIENT","Recipient could not be resolved")
  ok=self~runtime~presence~unsubscribe(recipient,decision)
  if \ok then return .MessagingPresenceDispatchResult~failed("UNSUBSCRIBE_FAILED","No current provider accepted unsubscribe")
  return .MessagingPresenceDispatchResult~new(.true,"UNSUBSCRIBE_PRESENCE",recipient,recipient,"presence subscription removed")

::class MessagingPresenceDispatchResult public
::method init
  expose success operation value semanticObject evidence errorCode
  use strict arg success, operation, value=.nil, semanticObject=.nil, evidence="", errorCode=""
  success=success; operation=operation; value=value; semanticObject=semanticObject; evidence=evidence; errorCode=errorCode
::attribute success get
::attribute operation get
::attribute value get
::attribute semanticObject get
::attribute evidence get
::attribute errorCode get
::method failed class
  use strict arg errorCode, evidence
  return self~new(.false,"FAILED",.nil,.nil,evidence,errorCode)

::requires "MessagingPresence.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
