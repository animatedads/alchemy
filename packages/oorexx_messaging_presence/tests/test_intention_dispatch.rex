parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

registry=.MessagingPresenceProviderRegistry~new
provider=.IntentDispatchProvider~new
registry~register(provider)
messaging=.Messaging~new(registry)
presence=.Presence~new(registry)
resolver=.RegisteredMessagingAddressResolver~new
selfAddress=.MessagingAddress~new("agent-alpha","example.test","worker-a")
bob=.MessagingAddress~new("agent-beta","example.test","worker-b")
resolver~register("bob",bob)
clock=.FixedClock~new("20261007T14:05:00")
runtime=.MessagingPresenceIntentionRuntime~new(messaging,presence,resolver,selfAddress,clock)
service=.IntentionService~new
.MessagingPresenceIntentionInstaller~install(service,registry,runtime)

sendDecision=service~input("send message to bob: TPS report is complete")
call assertEq "READY",sendDecision~status,"send decision ready"
call assertTrue sendDecision~event~isA(.MessagingPresenceSendEvent),"send event is executable semantic event"
call assertEq "bob",sendDecision~proposal~slot("RECIPIENT")~value,"recipient slot"
call assertEq "TPS report is complete",sendDecision~proposal~slot("BODY")~value,"body slot"
sendResult=service~dispatch(sendDecision)
call assertTrue sendResult~success,"send dispatch success"
call assertTrue sendResult~semanticObject~isA(.Message),"semantic Message carried to event"
call assertTrue provider~lastMessage == sendResult~semanticObject,"provider received exact Message object"
call assertTrue provider~lastMessage~toAddress == bob,"provider retained exact recipient object"
call assertTrue provider~lastMessage~fromAddress == selfAddress,"provider retained exact sender object"
call assertEq "TPS report is complete",provider~lastMessage~body,"provider message body"

checkDecision=service~input("is bob available")
call assertEq "READY",checkDecision~status,"presence check ready"
checkResult=service~dispatch(checkDecision)
call assertTrue checkResult~success,"presence check success"
call assertTrue checkResult~value~isA(.PresenceState),"presence check returns PresenceState object"
call assertTrue checkResult~value~address == bob,"presence object keeps recipient identity"
call assertEq .PresenceAvailability~AVAILABLE,checkResult~value~availability,"presence availability"

publishDecision=service~input("set my presence to busy: reviewing TPS reports")
call assertEq "READY",publishDecision~status,"publish ready"
publishResult=service~dispatch(publishDecision)
call assertTrue publishResult~success,"publish success"
call assertTrue provider~lastPresence == publishResult~semanticObject,"provider got exact PresenceState"
call assertEq .PresenceAvailability~BUSY,provider~lastPresence~availability,"busy maps semantically"
call assertEq "reviewing TPS reports",provider~lastPresence~statusText,"status text carried"

subDecision=service~input("subscribe to bob presence")
call assertEq "READY",subDecision~status,"subscribe ready"
subResult=service~dispatch(subDecision)
call assertTrue subResult~success,"subscribe success"
call assertTrue provider~lastSubscriptionAddress == bob,"subscribe resolved semantic address"

unsubDecision=service~input("stop presence updates for bob")
call assertEq "READY",unsubDecision~status,"unsubscribe ready"
unsubResult=service~dispatch(unsubDecision)
call assertTrue unsubResult~success,"unsubscribe success"
call assertTrue provider~lastUnsubscriptionAddress == bob,"unsubscribe resolved semantic address"

say "PASS test_intention_dispatch"
exit 0

assertEq: procedure
 use arg e,a,l
 if e==a then return
 say "FAIL" l "expected="e "actual="a
 exit 1
assertTrue: procedure
 use arg v,l
 if v then return
 say "FAIL" l
 exit 1

::class FixedClock public
::method init
 expose value
 use strict arg value
::method now
 expose value
 return value

::class IntentDispatchProvider public subclass MessagingPresenceProvider
::method init
 expose lastMessage lastPresence lastSubscriptionAddress lastUnsubscriptionAddress
 lastMessage=.nil
 lastPresence=.nil
 lastSubscriptionAddress=.nil
 lastUnsubscriptionAddress=.nil
::attribute lastMessage get
::attribute lastPresence get
::attribute lastSubscriptionAddress get
::attribute lastUnsubscriptionAddress get
::method providerId
 return "intent-dispatch-probe"
::method offers
 use strict arg context=.nil
 caps=.MessagingPresenceCapabilities~new(.array~of(.MessagingPresenceCapability~SEND_MESSAGE, -
     .MessagingPresenceCapability~CHECK_PRESENCE,.MessagingPresenceCapability~PUBLISH_PRESENCE, -
     .MessagingPresenceCapability~SUBSCRIBE_PRESENCE,.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE))
 return .array~of(.MessagingPresenceOffer~new(self,caps,10))
::method send
 expose lastMessage
 use strict arg message, context=.nil
 lastMessage=message
 return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~SENT,message,self~providerId,"probe accepted semantic object")
::method presence
 use strict arg address, context=.nil
 return .PresenceState~new(address,.PresenceAvailability~AVAILABLE,"ready","20261007T14:05:00",self~providerId)
::method publishPresence
 expose lastPresence
 use strict arg state, context=.nil
 lastPresence=state
 return .true
::method subscribePresence
 expose lastSubscriptionAddress
 use strict arg address, context=.nil
 lastSubscriptionAddress=address
 return .true
::method unsubscribePresence
 expose lastUnsubscriptionAddress
 use strict arg address, context=.nil
 lastUnsubscriptionAddress=address
 return .true

::requires "MessagingPresence.cls"
::requires "MessagingPresenceIntentions.cls"
