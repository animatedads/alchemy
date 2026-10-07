call main
exit 0

main:
  a=.RegisteredSocketAddressProvider~new
  a~register("secure",.SocketAddresses~tls("192.0.2.8",443,"tls/queue-control"))
  material=.FakeMaterialProvider~new
  tls=.TLSSocketBinding~new(.FakeTcpBinding~new,.FakeTlsWrapper~new,material)
  p=.SocketProvider~new(a)
  p~registerBinding("TLS",tls)

  sender=p~sender("secure")
  call assert sender~tag="TLS-SENDER:tls/queue-control","TLS sender wrapped"
  call assert material~lastProfile="tls/queue-control","central profile resolution"
  call assert material~lastRole="SENDER","sender role"

  listener=p~listener("secure")
  call assert listener~tag="TLS-LISTENER:tls/queue-control","TLS listener wrapped"
  call assert material~lastRole="LISTENER","listener role"

  say "PASS TLS security-profile boundary"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeBase public
::method close
  return 0

::class FakeTcpBinding public subclass SocketTransportBinding
::method sender
  use strict arg address
  return .FakeBase~new
::method listener
  use strict arg address, backlog=32
  return .FakeBase~new

::class FakeMaterialProvider public subclass SocketSecurityMaterialProvider
::method init
  expose lastProfile lastRole
  lastProfile=""; lastRole=""
::attribute lastProfile get
::attribute lastRole get
::method resolve
  expose lastProfile lastRole
  use strict arg securityProfile, role
  lastProfile=securityProfile; lastRole=role
  d=.directory~new; d["profile"]=securityProfile
  return d

::class FakeTlsHandle public
::method init
  expose tag
  use strict arg tag
::attribute tag get

::class FakeTlsWrapper public
::method wrapSender
  use strict arg base, material, address
  return .FakeTlsHandle~new("TLS-SENDER:"||material["profile"])
::method wrapListener
  use strict arg base, material, address
  return .FakeTlsHandle~new("TLS-LISTENER:"||material["profile"])

::requires "SocketProvider.cls"
::requires "TLSSocketFamily.cls"
