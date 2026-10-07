call addpath
addresses=.RegisteredSocketAddressProvider~new
addresses~register("storage.peer.B",.SocketAddresses~unix("/tmp/storage-peer-b.sock","storage.peer.B"),"SENDER")
addresses~register("storage.peer.A",.SocketAddresses~unix("/tmp/storage-peer-a.sock","storage.peer.A"),"LISTENER")
binding=.FakeBinding~new
selector=.SocketSelector~new(addresses)
selector~registerBinding(.SocketTransportKind~UNIX,binding)
peers=.StorageMeshPeerDirectory~new
peers~put(.StorageMeshPeer~new("B","storage.peer.B","SPARE",7))
port=.StoragePeerSocketPort~new(selector,addresses,"storage.peer.A",peers)
info=port~describePeer("B")
call ok info["status"]="RESOLVED","peer logical service resolves"
call ok info["family"]="UNIX","estate socket family exposed"
s=port~sender("B")
call ok s<>.nil & binding~lastAddress~logicalName="storage.peer.B","sender acquired only through SocketProvider"
call ok port~listener<>.nil & binding~lastListener~logicalName="storage.peer.A","listener acquired only through SocketProvider"
s~close
say "PASS Storage mesh estate SocketProvider projection"
exit 0
ok: procedure
  parse arg truth,label
  if truth then return
  say "FAIL" label; exit 1
addpath:
  here=directory(); call value "REXX_PATH",here||"/src:"||here||"/../socket_dev8/oorexx_socket_provider_v0.1-dev8/src:"||value("REXX_PATH",,"ENVIRONMENT"),"ENVIRONMENT"; return
::class FakeEndpoint
::method init; expose rawAddress; use strict arg rawAddress
::method asStream; expose rawAddress; return .FakeStream~new(rawAddress)
::method close; return
::class FakeStream
::method init; expose value; use strict arg value
::attribute value get
::method close; return
::class FakeBinding public subclass SocketTransportBinding
::attribute lastAddress get
::attribute lastListener get
::method sender
  expose lastAddress
  use strict arg address
  lastAddress=address; return .FakeEndpoint~new(address)
::method listener
  expose lastListener
  use strict arg address,backlog
  lastListener=address; return .FakeEndpoint~new(address)
::requires "StorageMesh.cls"
::requires "SocketProvider.cls"
