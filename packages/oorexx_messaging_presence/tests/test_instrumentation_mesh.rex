parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

identity=.InstrumentationCodec~identity("alchemy","messaging-presence","mp-1","node-a","","MESSAGING_PRESENCE")
telemetry=.MessagingPresenceInstrumentation~new(identity)
telemetry~setHealth(.InstrumentationHealth~HEALTHY)

alice=.MessagingAddress~new("alice","example.test")
bob=.MessagingAddress~new("bob","example.test")
delegate=.TelemetryProbeProvider~new(alice,bob)
provider=.InstrumentedMessagingPresenceProvider~new(delegate,telemetry)
registry=.MessagingPresenceProviderRegistry~new
registry~register(provider)
msgSvc=.Messaging~new(registry)
presSvc=.Presence~new(registry)

m=.Message~new("m1",alice,bob,"hello")
r=msgSvc~send(m)
call assertTrue r~sent,"instrumented send"
call assertTrue presSvc~publish(.PresenceState~new(alice,.PresenceAvailability~BUSY,"working")),"instrumented presence publish"
state=presSvc~current(bob)
call assertEq .PresenceAvailability~AVAILABLE,state~availability,"instrumented presence query"
call assertTrue presSvc~subscribe(bob),"instrumented subscribe"
call assertTrue presSvc~unsubscribe(bob),"instrumented unsubscribe"
inbound=msgSvc~receive
call assertTrue inbound~isA(.Message),"instrumented receive semantic message"

raw=.TelemetryProbeTransport~new
wire=.InstrumentedXmppTransport~new(raw,telemetry,"xmpp")
call assertTrue wire~open,"instrumented transport open"
call assertEq 3,wire~write("abc"),"transport write length"
raw~queueRead("wxyz")
call assertEq "wxyz",wire~read(10),"transport read payload"
call assertTrue wire~close,"instrumented transport close"

snapshot=telemetry~snapshot("2026-10-08T09:00:00Z")
call assertEq "messaging-presence",snapshot["identity"]["service_id"],"stable service identity"
call assertEq telemetry~semanticRef,snapshot["semantic_ref"],"stable semantic ref"
call assertEq .InstrumentationHealth~HEALTHY,snapshot["health"],"health preserved"
call assertEq 6,sampleValue(snapshot,.InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL,-1),"request accepted total"
call assertEq 6,sampleValue(snapshot,.InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL,-1),"request completed total"
call assertEq 0,sampleValue(snapshot,.InstrumentationVocabulary~REQUEST_FAILED_TOTAL,0),"request failed total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~MESSAGING_SEND_TOTAL,-1),"send total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~MESSAGING_RECEIVED_TOTAL,-1),"received total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~PRESENCE_PUBLISH_TOTAL,-1),"presence publish total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~PRESENCE_QUERY_TOTAL,-1),"presence query total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~PRESENCE_OBSERVED_TOTAL,-1),"presence observed total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~PRESENCE_SUBSCRIBE_TOTAL,-1),"presence subscribe total"
call assertEq 1,sampleValue(snapshot,.MessagingPresenceMetric~PRESENCE_UNSUBSCRIBE_TOTAL,-1),"presence unsubscribe total"
call assertEq 3,sampleValue(snapshot,.InstrumentationVocabulary~BYTES_OUT_TOTAL,-1),"wire bytes out"
call assertEq 4,sampleValue(snapshot,.InstrumentationVocabulary~BYTES_IN_TOTAL,-1),"wire bytes in"
call assertEq "CLOSED",sampleValue(snapshot,.MessagingPresenceMetric~TRANSPORT_STATE,""),"transport state"

cap=telemetry~capability
call assertEq .InstrumentationContract~CAPABILITY_SCHEMA,cap["schema"],"instrumentation capability schema"
call assertEq 0,cap["commands"]~items,"telemetry grants no management command surface"

meshRegistry=.InstrumentationRegistry~new
meshRegistry~register("messaging-presence",telemetry)
meshService=.InstrumentationService~new(meshRegistry)
collector=.InstrumentationCollector~new(8)
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,"node-a")
publisher=.InstrumentationPublisher~new("mp-publisher",meshService,transport,"collector-a")
published=publisher~publish("2026-10-08T09:00:01Z")
call assertTrue published~ok,"mesh publication accepted"
latest=collector~latestBySemanticRef(telemetry~semanticRef)
call assertTrue latest<>.nil,"collector latest by semantic ref"
series=collector~series(telemetry~semanticRef,.MessagingPresenceMetric~MESSAGING_SEND_TOTAL)
call assertEq 1,series~items,"collector series uses common mesh history"
call assertEq 1,series[1]["value"],"collector series value"

command=.InstrumentationCodec~command("cmd-1",identity,"SEND_MESSAGE",.directory~new,"2026-10-08T09:00:02Z","authority-test")
reply=meshService~handleFrom("peer-a",command)
call assertEq "DENIED",reply["status"],"management command denied without authorizer"
call assertEq "NO_MANAGEMENT_AUTHORITY",reply["code"],"no implicit mutation authority"

say "PASS test_instrumentation_mesh"
exit 0

sampleValue: procedure
  use arg snapshot,name,defaultValue
  do sample over snapshot["samples"]
    if sample["name"]=name then return sample["value"]
  end
  return defaultValue

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

::class TelemetryProbeProvider public subclass MessagingPresenceProvider
::method init
  expose alice bob receiveCount
  use strict arg aliceArg,bobArg
  alice=aliceArg; bob=bobArg; receiveCount=0
::method providerId
  return "probe"
::method offers
  use strict arg context=.nil
  caps=.MessagingPresenceCapabilities~new(.array~of( -
    .MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~RECEIVE_MESSAGE, -
    .MessagingPresenceCapability~PUBLISH_PRESENCE,.MessagingPresenceCapability~CHECK_PRESENCE, -
    .MessagingPresenceCapability~SUBSCRIBE_PRESENCE,.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE))
  return .array~of(.MessagingPresenceOffer~new(self,caps,10,.true,"","probe available"))
::method send
  use strict arg message, context=.nil
  return .MessagingDeliveryResult~new(.MessagingDeliveryStatus~SENT,message,self~providerId,"probe sent")
::method receive
  expose alice bob receiveCount
  use strict arg context=.nil
  receiveCount+=1
  if receiveCount>1 then return .nil
  return .Message~new("in-1",bob,alice,"reply")
::method publishPresence
  use strict arg state, context=.nil
  return .true
::method presence
  use strict arg address, context=.nil
  return .PresenceState~new(address,.PresenceAvailability~AVAILABLE,"ready","","probe")
::method subscribePresence
  use strict arg address, context=.nil
  return .true
::method unsubscribePresence
  use strict arg address, context=.nil
  return .true

::class TelemetryProbeTransport public subclass XmppTransport
::method init
  expose reads opened secureFlag
  reads=.queue~new; opened=.false; secureFlag=.false
::method queueRead
  expose reads
  use strict arg bytes
  reads~queue(bytes)
  return self
::method open
  expose opened
  use strict arg context=.nil
  opened=.true
  return .true
::method write
  expose opened
  use strict arg bytes, context=.nil
  if \opened then return -1
  return length(bytes)
::method read
  expose reads opened
  use strict arg maximumBytes, context=.nil
  if \opened | reads~items=0 then return .nil
  return reads~pull
::method close
  expose opened
  opened=.false
  return .true
::method secure
  expose secureFlag
  return secureFlag
::method supportsStartTls
  return .true
::method startTls
  expose secureFlag
  use strict arg context=.nil
  secureFlag=.true
  return .true

::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "MessagingPresenceInstrumentation.cls"
::requires "InstrumentationMesh.cls"
