/* tls_family_example.rex
 * Family example: the application names a service; address/provider layers
 * select TLS. Private key/cert/trust material never appears in the address.
 */
addresses=.RegisteredSocketAddressProvider~new
addresses~register("queue.control",.SocketAddresses~tls("192.0.2.24",7443,"queue/control-prod"))

sockets=.SocketSelector~new(addresses)
ignore=.TLSFamilyInstaller~install(sockets,.ExampleTcpBinding~new,.ExampleTlsEngine~new,.ExampleSecurityAuthority~new)

say "scheme=" sockets~family("queue.control")~scheme
say "family=" sockets~family("queue.control")~addressFamily
say "secure=" sockets~capabilities("queue.control")~secure
say "sender=" sockets~sender("queue.control")
exit 0

::class ExampleEndpoint public
::method init
  expose text
  use strict arg text
  text=text
::method string
  expose text
  return text
::method close
  return 0

::class ExampleTcpBinding public subclass SocketTransportBinding
::method listener
  use strict arg address, backlog=32
  return .ExampleEndpoint~new("tcp listener "||address~host||":"||address~port)
::method sender
  use strict arg address
  return .ExampleEndpoint~new("tcp sender "||address~host||":"||address~port)

::class ExampleSecurityAuthority public subclass SocketSecurityMaterialProvider
::method resolve
  use strict arg profile, role
  material=.directory~new
  material["profile"]=profile
  material["authority"]="SecretBroker-or-platform-key-authority"
  return material

::class ExampleTlsEngine public subclass TLSEngine
::method wrapListener
  use strict arg base, material, address
  return .ExampleEndpoint~new("TLS listener profile="||material["profile"])
::method wrapSender
  use strict arg base, material, address
  return .ExampleEndpoint~new("TLS sender profile="||material["profile"])

::requires "SocketProvider.cls"
::requires "TLSSocketFamily.cls"
