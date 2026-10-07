parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

service=.IntentionService~new
registry=.MessagingPresenceProviderRegistry~new
p=.IntentProbeProvider~new
registry~register(p)
.MessagingPresenceIntentionInstaller~install(service,registry)

d1=service~input("send a message to agent beta")
call assertEq "READY",d1~status,"send meaning available from live surface"
call assertEq "SEND_MESSAGE",d1~event,"semantic event"
call assertEq 1,service~discoverySurfaces~items,"surface discovered"
g1=d1~discoveryGeneration

p~presenceOnly
d2=service~input("send a message to agent beta")
call assertEq "UNKNOWN",d2~status,"send disappears when provider loses send capability"
d3=service~input("is agent beta available")
call assertEq "READY",d3~status,"presence still discoverable"
call assertEq "CHECK_PRESENCE",d3~event,"presence event"
call assertTrue d3~discoveryGeneration>g1,"generation advanced with capability change"

p~off
d4=service~input("is agent beta available")
call assertEq "UNKNOWN",d4~status,"presence disappears when provider unavailable"
call assertEq 0,service~discoverySurfaces~items,"no stale surface remains"
say "PASS test_intention_discovery"
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

::class IntentProbeProvider public subclass MessagingPresenceProvider
::method init
 expose mode
 mode="ALL"
::method providerId
 return "intent-probe"
::method presenceOnly
 expose mode
 mode="PRESENCE"
 return self
::method off
 expose mode
 mode="OFF"
 return self
::method offers
 expose mode
 use arg context=.nil
 if mode="OFF" then return .array~new
 caps=.MessagingPresenceCapabilities~new
 if mode="ALL" then caps~add(.MessagingPresenceCapability~SEND_MESSAGE)
 caps~add(.MessagingPresenceCapability~CHECK_PRESENCE)
 return .array~of(.MessagingPresenceOffer~new(self,caps,10))
::requires "MessagingPresence.cls"
::requires "MessagingPresenceIntentions.cls"
