/* TLS as the family example for provider extensibility. */
call main
exit 0

main:
  ap=.RegisteredSocketAddressProvider~new
  ap~register("queue.secure",.SocketAddresses~tls("192.0.2.24",7443,"queue/control-prod"))

  selector=.SocketSelector~new(ap)
  base=.FakeStreamBinding~new
  engine=.FakeTlsEngine~new
  materials=.FakeSecurityMaterialProvider~new
  ignore=.TLSFamilyInstaller~install(selector,base,engine,materials)

  family=selector~family("queue.secure")
  caps=selector~capabilities("queue.secure")
  call assert family~scheme="tls","TLS scheme"
  call assert family~addressFamily="TLS_INET","TLS address family"
  call assert caps~secure,"TLS advertises secure capability"
  call assert caps~stream,"TLS retains stream capability"

  sender=selector~sender("queue.secure")
  call assert sender~tag="tls-sender:queue/control-prod","TLS sender created through family"
  call assert materials~lastProfile="queue/control-prod","keys resolved by one material authority"
  call assert materials~lastRole="SENDER","sender role reaches key authority"

  listener=selector~listener("queue.secure",19)
  call assert listener~tag="tls-listener:queue/control-prod:19","TLS listener created through family"
  call assert materials~lastRole="LISTENER","listener role reaches key authority"

  address=ap~senderAddress("queue.secure")
  call assert address~securityProfile="queue/control-prod","address stores profile reference"
  call assert pos("KEY",address~canonical)=0,"canonical address contains no key material"

  say "PASS socket.family/0.1 TLS example"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeNative public
::method close
  return 0

::class FakeStreamEndpoint public
::method init
  expose tag
  use strict arg tag
::attribute tag get
::method close
  return 0

::class FakeStreamBinding public subclass SocketTransportBinding
::method sender
  use strict arg address
  return .FakeStreamEndpoint~new("tcp-sender")
::method listener
  use strict arg address, backlog=32
  return .FakeStreamEndpoint~new("tcp-listener:"||backlog)

::class FakeSecurityMaterialProvider public subclass SocketSecurityMaterialProvider
::method init
  expose lastProfile lastRole
  lastProfile=""; lastRole=""
::attribute lastProfile get
::attribute lastRole get
::method resolve
  expose lastProfile lastRole
  use strict arg profile, role
  lastProfile=profile; lastRole=role
  d=.directory~new
  d["profile"]=profile
  return d

::class FakeTlsEndpoint public
::method init
  expose tag
  use strict arg tag
::attribute tag get
::method close
  return 0

::class FakeTlsEngine public subclass TLSEngine
::method wrapSender
  use strict arg base, material, address
  return .FakeTlsEndpoint~new("tls-sender:"||material["profile"])
::method wrapListener
  use strict arg base, material, address
  return .FakeTlsEndpoint~new("tls-listener:"||material["profile"]||":"||19)

::requires "SocketProvider.cls"
::requires "TLSSocketFamily.cls"
