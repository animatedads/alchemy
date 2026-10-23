parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
t=.NoUpgradeTransport~new
t~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'><required/></starttls></stream:features>")
s=.XmppSessionEngine~new(t,"example.test",.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret")))
call assertTrue s~connect,"connect"
s~pump
call assertEq .XmppSessionState~FAILED,s~state,"fails without upgrade seam"
call assertEq "STARTTLS_UNAVAILABLE",s~failure~code,"failure code"
call assertEq 1,t~writes~items,"only initial stream written"
call assertTrue pos("secret",t~joinedWrites)=0,"secret never emitted"
t2=.NoUpgradeTransport~new
t2~queueRead("<stream:stream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features>")
s2=.XmppSessionEngine~new(t2,"example.test",.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret")))
call assertTrue s2~connect,"connect no tls"
s2~pump
call assertEq .XmppSessionState~FAILED,s2~state,"no TLS rejected"
call assertEq "TLS_REQUIRED",s2~failure~code,"TLS required failure"
call assertTrue pos("secret",t2~joinedWrites)=0,"secret never emitted on downgrade"
say "PASS test_xmpp_session_fail_closed"; exit 0
assertEq: procedure; use arg e,a,l; if e==a then return; say "FAIL" l "expected="e "actual="a; exit 1
assertTrue: procedure; use arg v,l; if v then return; say "FAIL" l; exit 1
::class NoUpgradeTransport public subclass XmppTransport
::method init; expose reads writes opened; reads=.queue~new; writes=.array~new; opened=.false
::attribute writes get
::method queueRead; expose reads; use strict arg chunk; reads~queue(chunk); return self
::method open; expose opened; use strict arg context=.nil; opened=.true; return .true
::method write; expose writes; use strict arg bytes, context=.nil; writes~append(bytes); return length(bytes)
::method read; expose reads; use strict arg maximumBytes, context=.nil; if reads~items=0 then return .nil; return reads~pull
::method secure; return .false
::method supportsStartTls; return .false
::method close; return .true
::method joinedWrites
  expose writes
  out=""
  do w over writes; out=out||w; end
  return out
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
