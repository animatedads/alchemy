listenerAddress=.SocketAddresses~tcp("192.0.2.1",9000,"LISTENER")
peerAddress=.SocketAddresses~tcp("198.51.100.22",41000,"PEER")
peer=.FakePeer~new(peerAddress)
nativeListener=.FakeListener~new(peer)
listener=.ProviderSocketListener~new(nativeListener,listenerAddress)
accepted=listener~accept
if accepted=.nil then exit 10
if accepted~address \== peerAddress then exit 11
if accepted~address == listenerAddress then exit 12
nativeListener2=.FakeListener~new(peer)
listener2=.ProviderSocketListener~new(nativeListener2,listenerAddress)
accepted2=listener2~tryAccept
if accepted2=.nil then exit 13
if accepted2~address \== peerAddress then exit 14
say "ACCEPTED_PEER_ADDRESS_IDENTITY_OK"
::class FakePeer
::method init
  expose address
  use strict arg address
::attribute address get
::method send; return 0
::method recv; return .nil
::method close; return 0
::class FakeListener
::method init
  expose peer
  use strict arg peer
::method accept
  expose peer
  return peer
::method tryAccept
  expose peer
  return peer
::method close; return 0
::requires "SocketProvider.cls"
