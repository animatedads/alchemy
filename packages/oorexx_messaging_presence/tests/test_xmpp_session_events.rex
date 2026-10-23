parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
t=.SecureTranscriptTransport~new
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features>")
t~queueRead("<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>")
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></stream:features>")
t~queueRead("<iq type='result' id='bind-1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><jid>alice@example.test/rexx</jid></bind></iq>")
s=.XmppSessionEngine~new(t,"example.test",.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret")),"rexx")
call assertTrue s~connect,"connect"
do i=1 to 4; s~pump; end
call assertEq .XmppSessionState~READY,s~state,"ready over already-secured transport"
t~queueRead("<message from='bob@example.test/phone' to='alice@example.test/rexx' id='m9'><subject>TPS</subject><body>Done &amp; filed</body><thread>t9</thread></message>")
e=s~receiveEvent
call assertTrue e~isA(.XmppInboundMessage),"inbound message event"
call assertEq "bob@example.test/phone",e~fromJid,"message sender"
call assertEq "Done & filed",e~body,"message body"
call assertEq "TPS",e~subject,"message subject"
t~queueRead("<message from='carol@example.test' to='alice@example.test/rexx'><body>Hello</body></message>")
p=.XmppMessagingPresenceProvider~new(s)
semantic=p~receive
call assertTrue semantic~isA(.Message),"semantic message projected"
call assertEq "carol",semantic~fromAddress~localId,"semantic sender"
call assertEq "Hello",semantic~body,"semantic body"
t~queueRead("<presence from='bob@example.test/phone'><show>dnd</show><status>reviewing TPS</status></presence>")
pe=s~receiveEvent
call assertTrue pe~isA(.XmppInboundPresence),"presence event"
call assertEq .PresenceAvailability~BUSY,pe~availability,"dnd maps busy"
call assertEq "reviewing TPS",pe~statusText,"status text"
call assertTrue s~currentPresence("bob@example.test/phone")==pe,"presence cache preserves event object"
t~queueRead("<presence from='bob@example.test' type='subscribe'/>")
ignored=s~receiveEvent
call assertTrue ignored=.nil,"subscription control not availability event"
say "PASS test_xmpp_session_events"; exit 0
assertEq: procedure; use arg e,a,l; if e==a then return; say "FAIL" l "expected="e "actual="a; exit 1
assertTrue: procedure; use arg v,l; if v then return; say "FAIL" l; exit 1
::class SecureTranscriptTransport public subclass XmppTransport
::method init; expose reads writes opened; reads=.queue~new; writes=.array~new; opened=.false
::attribute writes get
::method queueRead; expose reads; use strict arg chunk; reads~queue(chunk); return self
::method open; expose opened; use strict arg context=.nil; opened=.true; return .true
::method write; expose writes opened; use strict arg bytes, context=.nil; if \opened then return -1; writes~append(bytes); return length(bytes)
::method read; expose reads opened; use strict arg maximumBytes, context=.nil; if \opened | reads~items=0 then return .nil; return reads~pull
::method secure; return .true
::method supportsStartTls; return .false
::method close; expose opened; opened=.false; return .true
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
