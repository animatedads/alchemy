parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
extensions=.MessagingPresenceExtensionRegistry~new
roomPlugin=.SemanticPlugin~new("example.group-conversation","GROUP_CONVERSATION",.Object~new)
pubPlugin=.SemanticPlugin~new("example.event-publication","EVENT_PUBLICATION",.Object~new)
extensions~register(roomPlugin,20); extensions~register(pubPlugin,30)
call assertEq 2,extensions~discover~items,"plugins discover independently"
selected=extensions~select("GROUP_CONVERSATION")
call assertTrue selected<>.nil,"semantic plugin selected"
call assertTrue selected~plugin == roomPlugin,"exact plugin object preserved"
call assertEq "GROUP_CONVERSATION",selected~semanticServiceId,"semantic service identity"
providers=.MessagingPresenceProviderRegistry~new
providers~register(.CoreProvider~new)
offer=providers~discover~at(1)
call assertTrue offer~capabilities~supports(.MessagingPresenceCapability~SEND_MESSAGE),"core send remains"
call assertTrue \offer~capabilities~supports("GROUP_CONVERSATION"),"plugin service is not smuggled into core capabilities"
roomPlugin~off
call assertEq 0,extensions~discover("GROUP_CONVERSATION")~items,"unavailable plugin disappears dynamically"
call assertEq 1,extensions~discover~items,"other plugin unaffected"
say "PASS test_extension_registry"; exit 0
assertEq: procedure; use arg e,a,l; if e==a then return; say "FAIL" l "expected="e "actual="a; exit 1
assertTrue: procedure; use arg v,l; if v then return; say "FAIL" l; exit 1
::class SemanticPlugin public subclass MessagingPresenceExtensionPlugin
::method init; expose id serviceId serviceObject on; use strict arg id, serviceId, serviceObject; on=.true
::method pluginId; expose id; return id
::method semanticServiceId; expose serviceId; return serviceId
::method service; expose serviceObject; return serviceObject
::method available; expose on; use strict arg context=.nil; return on
::method off; expose on; on=.false; return self
::class CoreProvider public subclass MessagingPresenceProvider
::method providerId; return "core"
::method offers
 use strict arg context=.nil
 caps=.MessagingPresenceCapabilities~new(.array~of(.MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~CHECK_PRESENCE))
 return .array~of(.MessagingPresenceOffer~new(self,caps,10))
::requires "MessagingPresence.cls"
::requires "MessagingPresenceExtensions.cls"
