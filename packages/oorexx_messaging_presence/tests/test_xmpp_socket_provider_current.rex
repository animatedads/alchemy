parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

tlsAddress=.SocketAddresses~tls("192.0.2.20",5222,"messaging/xmpp-client","messaging.xmpp")
sp=.FakeSocketProvider~new(tlsAddress)
t=.XmppSocketTransport~new(sp,"messaging.xmpp")
call assertTrue t~open,"current SocketProvider stream contract opens"
call assertTrue t~secure,"TLS SocketAddress is recognised as protected transport"
call assertTrue \t~supportsStartTls,"generic same-stream STARTTLS is not assumed"
call assertEq "TLS",t~socketAddress~transport,"TLS transport object preserved"
call assertEq "messaging/xmpp-client",t~socketAddress~securityProfile,"security profile reference preserved"
call assertTrue t~close,"close"

plainAddress=.SocketAddresses~tcp("192.0.2.20",5222,"messaging.xmpp")
sp2=.FakeSocketProvider~new(plainAddress)
t2=.XmppSocketTransport~new(sp2,"messaging.xmpp")
call assertTrue t2~open,"plain stream opened"
call assertTrue \t2~secure,"TCP stream is not mislabeled secure"

say "PASS test_xmpp_socket_provider_current"
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

::class FakeStream public
::method init
  expose address
  use strict arg address
::method socketAddress
  expose address
  return address
::method write
  use strict arg bytes
  return length(bytes)
::method read
  use strict arg maximumBytes
  return .nil
::method close
  return .true

::class FakeSocketProvider public
::method init
  expose address
  use strict arg address
::method streamSender
  expose address
  use strict arg logicalName
  return .FakeStream~new(address)

::requires "MessagingPresence.cls"
::requires "SocketProvider.cls"
::requires "XmppMessagingPresenceProvider.cls"
