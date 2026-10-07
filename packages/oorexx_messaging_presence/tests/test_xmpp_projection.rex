parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

session=.FakeXmppSession~new
provider=.XmppMessagingPresenceProvider~new(session)
registry=.MessagingPresenceProviderRegistry~new
registry~register(provider)
a=.MessagingAddress~new("agent-a","example.test","worker")
b=.MessagingAddress~new("agent-b","example.test")
meta=.directory~new; meta["OBJECT"]="preserved"
m=.Message~new("m<&1",a,b,"A < B & C","subject","text/plain","thread-1","",.nil,meta)
r=.Messaging~new(registry)~send(m)
call assertEq "SENT",r~status,"XMPP provider selected"
call assertContains session~lastXml,"to='agent-b@example.test'","recipient projected"
call assertContains session~lastXml,"id='m&lt;&amp;1'","attribute escaped"
call assertContains session~lastXml,"<body>A &lt; B &amp; C</body>","body escaped"
call assertTrue r~message==m,"semantic Message survives provider call"
pstate=.PresenceState~new(a,.PresenceAvailability~BUSY,"heads down")
call assertTrue .Presence~new(registry)~publish(pstate),"presence publish"
call assertContains session~lastXml,"<show>dnd</show>","busy projected to XMPP show"
call assertTrue .Presence~new(registry)~subscribe(b),"presence subscribe"
call assertContains session~lastXml,"type='subscribe'","subscription stanza"
session~queueMessage(.XmppInboundMessage~new("m2","agent-b@example.test","agent-a@example.test/worker","hello back"))
incoming=.Messaging~new(registry)~receive
call assertEq "hello back",incoming~body,"inbound semantic message"
call assertEq "agent-b",incoming~fromAddress~localId,"inbound address decoded"
say "PASS test_xmpp_projection"
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
assertContains: procedure
 use arg hay,needle,l
 if pos(needle,hay)>0 then return
 say "FAIL" l "missing="needle "in="hay
 exit 1

::class FakeXmppSession public subclass XmppSession
::method init
 expose lastXml queued
 lastXml=""; queued=.nil
::attribute lastXml get
::method available
 use arg context=.nil
 return .true
::method capabilities
 use arg context=.nil
 return .MessagingPresenceCapabilities~new(.array~of(.MessagingPresenceCapability~SEND_MESSAGE,.MessagingPresenceCapability~RECEIVE_MESSAGE,.MessagingPresenceCapability~PUBLISH_PRESENCE,.MessagingPresenceCapability~CHECK_PRESENCE,.MessagingPresenceCapability~SUBSCRIBE_PRESENCE,.MessagingPresenceCapability~UNSUBSCRIBE_PRESENCE))
::method sendXml
 expose lastXml
 use arg xml,context=.nil
 lastXml=xml
 return .true
::method queueMessage
 expose queued
 use arg event
 queued=event
 return self
::method receiveEvent
 expose queued
 use arg context=.nil
 event=queued; queued=.nil
 return event
::method currentPresence
 use arg jid,context=.nil
 return .XmppInboundPresence~new(jid,.PresenceAvailability~AVAILABLE,"ready")
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
