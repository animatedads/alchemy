numeric digits 30
addresses=.RegisteredSocketAddressProvider~new
addresses~register("imap.test",.SocketAddresses~tcp("127.0.0.1",1143,"imap.test"),.SocketRole~LISTENER)
provider=.SocketProvider~new(addresses)
binding=.FixtureTcpBinding~new
provider~registerBinding(.SocketTransportKind~TCP,binding)
auth=.ImapTestAuthenticationProvider~new
session=.ImapServerSession~new(auth,.ImapMemoryMailboxProvider~new,.ImapTestAllowAllMailboxAuthority~new,.false)
server=.ImapSocketProviderServer~new(provider,"imap.test")
served=server~serveOne(session)
call assert served~ok,"SocketProvider serveOne succeeds"
wire=binding~connection~written
call assert wire~pos("ooRexx IMAP server core ready")>0,"greeting written"
call assert wire~pos("A1 OK CAPABILITY completed")>0,"CAPABILITY served"
call assert wire~pos("A2 OK LOGOUT completed")>0,"LOGOUT served"
say "PASS test_socket_provider_server"
exit 0

assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::class FixtureTcpBinding public subclass SocketTransportBinding
::method init
  expose connection
  connection=.FixtureNativeConnection~new
::attribute connection get
::method listener
  expose connection
  use strict arg address,backlog=32
  return .ProviderSocketListener~new(.FixtureNativeListener~new(connection),address)
::method sender
  use strict arg address
  return .nil

::class FixtureNativeListener public
::method init
  expose connection
  use strict arg connectionArg
  connection=connectionArg
::method accept
  expose connection
  return connection
::method close
  return 0

::class FixtureNativeConnection public
::method init
  expose incoming written closed
  incoming="A1 CAPABILITY"||'0d0a'x||"A2 LOGOUT"||'0d0a'x
  written=""; closed=.false
::attribute written get
::method recv
  expose incoming closed
  use strict arg maximumBytes
  if closed then return ""
  if incoming="" then return ""
  n=maximumBytes
  if n>incoming~length then n=incoming~length
  chunk=incoming~left(n)
  incoming=incoming~substr(n+1)
  return chunk
::method send
  expose written closed
  use strict arg bytes
  if closed then return -1
  written=written||bytes
  return bytes~length
::method close
  expose closed
  closed=.true
  return 0

::requires "ImapSocketProviderBinding.cls"
