parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
t=.FakeTranscriptTransport~new(.false,.true)
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'><required/></starttls></stream:features>")
t~queueRead("<proceed xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features>")
t~queueRead("<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>")
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></stream:features>")
t~queueRead("<iq type='result' id='bind-1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><jid>alice@example.test/rexx</jid></bind></iq>")
creds=.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret"))
s=.XmppSessionEngine~new(t,"example.test",creds,"rexx")
call assertTrue s~connect,"session connect"
call assertEq .XmppSessionState~STREAM_SENT,s~state,"initial stream state"
do i=1 to 6; s~pump; end
call assertEq .XmppSessionState~READY,s~state,"session ready"
call assertEq "alice@example.test/rexx",s~boundJid,"bound jid"
call assertTrue s~available,"available only after bind"
call assertEq 1,t~tlsCalls,"single TLS upgrade"
call assertContains t~writes[2],"<starttls","STARTTLS request"
call assertContains t~writes[4],"mechanism='PLAIN'","SASL PLAIN selected"
call assertTrue pos("secret",t~writes[4])=0,"secret not sent in clear XML"
call assertContains t~writes[6],"<resource>rexx</resource>","resource bind"
say "PASS test_xmpp_session_handshake"; exit 0
assertEq: procedure; use arg e,a,l; if e==a then return; say "FAIL" l "expected="e "actual="a; exit 1
assertTrue: procedure; use arg v,l; if v then return; say "FAIL" l; exit 1
assertContains: procedure; use arg hay,needle,l; if pos(needle,hay)>0 then return; say "FAIL" l "missing="needle "in="hay; exit 1
::class FakeTranscriptTransport public subclass XmppTransport
::method init
  expose reads writes secureFlag startTlsCap tlsCalls opened
  use strict arg secureFlag=.false, startTlsCap=.true
  reads=.queue~new; writes=.array~new; tlsCalls=0; opened=.false
::attribute writes get
::attribute tlsCalls get
::method queueRead; expose reads; use strict arg chunk; reads~queue(chunk); return self
::method open; expose opened; use strict arg context=.nil; opened=.true; return .true
::method write; expose writes opened; use strict arg bytes, context=.nil; if \opened then return -1; writes~append(bytes); return length(bytes)
::method read; expose reads opened; use strict arg maximumBytes, context=.nil; if \opened | reads~items=0 then return .nil; return reads~pull
::method secure; expose secureFlag; return secureFlag
::method supportsStartTls; expose startTlsCap; return startTlsCap
::method startTls; expose secureFlag tlsCalls; use strict arg context=.nil; tlsCalls+=1; secureFlag=.true; return .true
::method close; expose opened; opened=.false; return .true
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
