call directory value("TEST_ROOT",,"ENVIRONMENT")

addresses=.RegisteredSocketAddressProvider~new
provider=.SocketProvider~new(addresses)
binding=.FixtureTcpBinding~new
provider~registerBinding(.SocketTransportKind~TCP,binding)
connector=.SmtpPlatformSocketConnector~new(provider,"smtp.test")
hop=.FixtureHop~new("192.0.2.55",2525)
r=connector~connect(hop)
if \r~ok then do; say "FAIL 1" r~code r~detail; exit 1; end
endpoint=r~value
if endpoint==.nil then do; say "FAIL 2"; exit 2; end
if endpoint~address~host<>"192.0.2.55" then do; say "FAIL 3"; exit 3; end
if endpoint~address~port<>2525 then do; say "FAIL 4"; exit 4; end
if endpoint~address~logicalName<>"smtp.test:192.0.2.55:2525" then do; say "FAIL 5"; exit 5; end
if binding~opens<>1 then do; say "FAIL 6"; exit 6; end
if endpoint~send("abc")<>3 then do; say "FAIL 7"; exit 7; end
if endpoint~recv(10)<>"250 fixture" then do; say "FAIL 8"; exit 8; end
endpoint~close
say "PASS SMTP SocketProvider v0.1 connector"
exit 0

::class FixtureHop public
::attribute host get
::attribute port get
::method init
  expose host port
  use strict arg hostArg,portArg
  host=hostArg; port=portArg
::method key
  expose host port
  return host||":"||port

::class FixtureTcpBinding public subclass SocketTransportBinding
::attribute opens get
::method init
  expose opens
  opens=0
::method sender
  expose opens
  use strict arg address
  opens+=1
  return .ProviderSocketConnection~new(.FixtureNativeSocket~new,address)
::method listener
  use strict arg address,backlog=32
  return .nil

::class FixtureNativeSocket public
::attribute closed get
::method init
  expose closed
  closed=.false
::method send
  use strict arg bytes
  return bytes~length
::method recv
  use strict arg maximumBytes
  return "250 fixture"
::method close
  expose closed
  closed=.true
  return 0

::requires "src/SmtpSocketProviderBinding.cls"
::requires "SocketProvider.cls"
