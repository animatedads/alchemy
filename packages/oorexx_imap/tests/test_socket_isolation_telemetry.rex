numeric digits 30

addresses=.RegisteredSocketAddressProvider~new
addresses~register("imap.telemetry.test",.SocketAddresses~tcp("127.0.0.1",1143,"imap.telemetry.test"),.SocketRole~LISTENER)
provider=.SocketProvider~new(addresses)
inner=.FixtureTcpBinding~new
recorder=.SocketTelemetryRecorder~new
telemetryBinding=.TelemetrySocketBinding~new(inner,recorder)
provider~registerBinding(.SocketTransportKind~TCP,telemetryBinding)

auth=.ImapTestAuthenticationProvider~new
session=.ImapServerSession~new(auth,.ImapMemoryMailboxProvider~new,.ImapTestAllowAllMailboxAuthority~new,.false)
server=.ImapSocketProviderServer~new(provider,"imap.telemetry.test")
served=server~serveOne(session)
call assert served~ok,'IMAP serves through socket telemetry decorator'
call assert inner~connection~written~pos('A2 OK LOGOUT completed')>0,'protocol output passes through decorator'
call assert recorder~counter('socket.accept.attempt')=1,'accept observed'
call assert recorder~counter('socket.accept.success')=1,'accept success observed'
call assert recorder~counter('socket.io.read.calls')>0,'read calls observed'
call assert recorder~counter('socket.io.write.calls')>0,'write calls observed'
call assert recorder~counter('socket.io.bytes.in')>0,'input bytes observed'
call assert recorder~counter('socket.io.bytes.out')>0,'output bytes observed'
call assert recorder~gauge('socket.connections.active')=0,'connection gauge settles after close'
call assert recorder~gauge('socket.listeners.active')=0,'listener gauge settles after close'
call assert \eventsContain(recorder~events,'A1 CAPABILITY'),'socket telemetry does not leak command payload'
call assert \eventsContain(recorder~events,'imap.telemetry.test'),'default socket telemetry does not leak logical service name'
call assert \eventsContain(recorder~events,'127.0.0.1'),'default socket telemetry does not leak host identity'

say 'PASS test_socket_isolation_telemetry'
exit 0

eventsContain: procedure
  use strict arg events,wanted
  do event over events
    if event~name~string~pos(wanted)>0 then return .true
    facts=event~facts
    do k over facts
      if k~string~pos(wanted)>0 then return .true
      v=facts[k]
      if v<>.nil then do
        if v~string~pos(wanted)>0 then return .true
      end
    end
  end
  return .false

assert: procedure
  use strict arg condition,message
  if \condition then do; say 'FAIL:' message; exit 1; end
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

::requires "SocketTelemetry.cls"
::requires "ImapSocketProviderBinding.cls"
