parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

registry=.MessagingPresenceProviderRegistry~new
p=.ProbeProvider~new
registry~register(p)
msgSvc=.Messaging~new(registry)
presSvc=.Presence~new(registry)
a=.MessagingAddress~new("a","example.test")
b=.MessagingAddress~new("b","example.test")
m=.Message~new("m1",a,b,"payload")
r=msgSvc~send(m)
call assertEq "SENT",r~status,"message sent"
call assertTrue p~lastMessage==m,"provider receives full Message object"
state=.PresenceState~new(a,.PresenceAvailability~BUSY,"working")
call assertTrue presSvc~publish(state),"presence published"
call assertTrue p~lastPresence==state,"provider receives full PresenceState object"
seen=presSvc~current(b)
call assertEq "AVAILABLE",seen~availability,"presence query"
call assertTrue seen~address==b,"presence query preserves requested object"
say "PASS test_access_classes"
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

::class ProbeProvider public subclass MessagingPresenceProvider
::method init
  expose lastMessage lastPresence
  lastMessage=.nil; lastPresence=.nil
::attribute lastMessage get
::attribute lastPresence get
::method providerId
  return "probe"
::method offers
  use arg context=.nil
  caps=.MessagingPresenceCapabilities~new(.array~of(.MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~PUBLISH_PRESENCE,.MessagingPresenceCapability~CHECK_PRESENCE))
  return .array~of(.MessagingPresenceOffer~new(self,caps,10))
::method send
  expose lastMessage
  use arg message, context=.nil
  lastMessage=message
  return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~SENT,message,self~providerId)
::method publishPresence
  expose lastPresence
  use arg state, context=.nil
  lastPresence=state
  return .true
::method presence
  use arg address, context=.nil
  return .PresenceState~new(address,.PresenceAvailability~AVAILABLE,"","","probe")
::requires "MessagingPresence.cls"
