parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

registry=.MessagingPresenceProviderRegistry~new
p=.ChangingProvider~new
registry~register(p)
call assertEq 1,registry~discover~items,"provider initially discovered"
s1=registry~surfaceSignature
p~disable
call assertEq 0,registry~discover~items,"provider disappears without registry restart"
s2=registry~surfaceSignature
call assertTrue s1<>s2,"dynamic signature changes with capability truth"
p~enablePresenceOnly
call assertEq 1,registry~discover~items,"provider returns"
call assertTrue registry~select(.MessagingPresenceCapability~CHECK_PRESENCE)<>.nil,"presence current"
call assertTrue registry~select(.MessagingPresenceCapability~SEND_MESSAGE)=.nil,"send not overclaimed"
say "PASS test_dynamic_provider_discovery"
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

::class ChangingProvider public subclass MessagingPresenceProvider
::method init
 expose mode
 mode="ALL"
::method providerId
 return "changing"
::method disable
 expose mode
 mode="OFF"
::method enablePresenceOnly
 expose mode
 mode="PRESENCE"
::method offers
 expose mode
 use arg context=.nil
 if mode="OFF" then return .array~new
 caps=.MessagingPresenceCapabilities~new
 if mode="ALL" then caps~add(.MessagingPresenceCapability~SEND_MESSAGE)
 caps~add(.MessagingPresenceCapability~CHECK_PRESENCE)
 return .array~of(.MessagingPresenceOffer~new(self,caps,20))
::requires "MessagingPresence.cls"
