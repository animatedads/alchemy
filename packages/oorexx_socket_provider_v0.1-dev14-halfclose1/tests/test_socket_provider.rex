call main
exit 0

main:
  a=.RegisteredSocketAddressProvider~new
  a~register("tcp.service",.SocketAddresses~tcp("127.0.0.1",9000))
  a~register("unix.service",.SocketAddresses~unix("/tmp/test.sock"))
  a~register("tls.service",.SocketAddresses~tls("10.0.0.4",9443,"service/server-a"))
  a~register("xtp.station",.SocketAddresses~xtp("02:11:22:33:44:55"))
  a~register("xtp.group",.SocketAddresses~xtp("group:memory-fabric",.true))

  call assert a~senderAddress("tcp.service")~host="127.0.0.1","TCP dotted address"
  call assert a~senderAddress("unix.service")~path="/tmp/test.sock","UNIX path"
  call assert a~senderAddress("tls.service")~securityProfile="service/server-a","TLS profile ref"
  call assert a~senderAddress("xtp.group")~multicast,"XTP group address identity"

  p=.SocketProvider~new(a)
  p~registerBinding("TCP",.FakeBinding~new("TCP"))
  p~registerBinding("UNIX",.FakeBinding~new("UNIX"))
  p~registerBinding("TLS",.FakeBinding~new("TLS"))
  p~registerBinding("XTP",.FakeBinding~new("XTP"))

  call assert p~sender("tcp.service")~tag="TCP:SENDER:127.0.0.1:9000","TCP sender dispatch"
  call assert p~listener("unix.service",17)~tag="UNIX:LISTENER:/tmp/test.sock:17","UNIX listener dispatch"
  call assert p~sender("tls.service")~tag="TLS:SENDER:10.0.0.4:9443","TLS sender dispatch"
  call assert p~sender("xtp.station")~tag="XTP:SENDER:02:11:22:33:44:55","XTP sender dispatch"
  call assert p~listener("xtp.group",8)~tag="XTP:LISTENER:group:memory-fabric:8","fake XTP group-address listener dispatch"
  call assert p~sender("missing")=.nil,"missing address fails closed"

  say "PASS socket.provider/0.1"
  say "PASS socket.address.provider/0.1"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeHandle public
::method init
  expose tag
  use strict arg tag
::attribute tag get

::class FakeBinding public subclass SocketTransportBinding
::method init
  expose kind
  use strict arg kind
  kind=kind
::method listener
  expose kind
  use strict arg address, backlog=32
  return .FakeHandle~new(kind||":LISTENER:"||self~where(address)||":"||backlog)
::method sender
  expose kind
  use strict arg address
  return .FakeHandle~new(kind||":SENDER:"||self~where(address))
::method where private
  use strict arg address
  select
    when address~transport=.SocketTransportKind~TCP | address~transport=.SocketTransportKind~TLS then return address~host||":"||address~port
    when address~transport=.SocketTransportKind~UNIX then return address~path
    otherwise return address~xtpAddress
  end

::requires "SocketProvider.cls"
