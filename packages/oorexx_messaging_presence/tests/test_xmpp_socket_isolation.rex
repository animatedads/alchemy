parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

sp=.FakeSocketProvider~new
transport=.XmppSocketTransport~new(sp,"messaging.xmpp")
call assertTrue transport~open,"transport opened via provider"
call assertEq "messaging.xmpp",sp~requested,"logical name passed to SocketProvider"
call assertEq 4,transport~write("PING"),"stream write delegated"
call assertEq "PONG",transport~read(4),"stream read delegated"
call assertTrue transport~socketAddress==sp~stream~socketAddress,"socket address object retained"
call assertTrue transport~close,"close delegated"
say "PASS test_xmpp_socket_isolation"
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

::class FakeAddress public
::method init
 self~name="isolated"
::attribute name
::class FakeStream public
::method init
 expose address
 address=.FakeAddress~new
::attribute socketAddress get
::method write
 use arg bytes
 return length(bytes)
::method read
 use arg n
 return left("PONG",n)
::method close
 return .true
::class FakeSocketProvider public
::method init
 expose requested stream
 requested=""; stream=.FakeStream~new
::attribute requested get
::attribute stream get
::method streamSender
 expose requested stream
 use arg name
 requested=name
 return stream
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
