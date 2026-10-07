/* TLSSocketFamily.cls
 * Concrete FAMILY EXAMPLE for the standard provider architecture.
 *
 * TLS is modelled as its own socket family/scheme above a base stream binding.
 * The TLS address contains only host/port + securityProfile. All key/cert/trust
 * resolution is concentrated in SocketSecurityMaterialProvider.
 */

::class SocketSecurityMaterialProvider public
::method resolve abstract

/* TLS engine contract. Implementations may use OpenSSL memory BIO / Foreign
 * Runtime or another in-process implementation. The engine receives resolved
 * material and the logical TLS SocketAddress, not key filenames from callers.
 */
::class TLSEngine public
::method wrapListener abstract
::method wrapSender abstract

::class TLSSocketBinding public subclass SocketTransportBinding
::method init
  expose baseBinding tlsEngine securityMaterials
  use strict arg baseBinding, tlsEngine, securityMaterials
  baseBinding=baseBinding
  tlsEngine=tlsEngine
  securityMaterials=securityMaterials
::method listener
  expose baseBinding tlsEngine securityMaterials
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~TLS then raise syntax 88.900 array("TLS binding requires TLS address")
  tcpAddress=.SocketAddresses~tcp(address~host,address~port,address~logicalName,address~metadata)
  base=baseBinding~listener(tcpAddress,backlog)
  if base=.nil then return .nil
  material=securityMaterials~resolve(address~securityProfile,.SocketRole~LISTENER)
  if material=.nil then do; base~close; return .nil; end
  wrapped=tlsEngine~wrapListener(base,material,address)
  if wrapped=.nil then do; base~close; return .nil; end
  return wrapped
::method sender
  expose baseBinding tlsEngine securityMaterials
  use strict arg address
  if address~transport<>.SocketTransportKind~TLS then raise syntax 88.900 array("TLS binding requires TLS address")
  tcpAddress=.SocketAddresses~tcp(address~host,address~port,address~logicalName,address~metadata)
  base=baseBinding~sender(tcpAddress)
  if base=.nil then return .nil
  material=securityMaterials~resolve(address~securityProfile,.SocketRole~SENDER)
  if material=.nil then do; base~close; return .nil; end
  wrapped=tlsEngine~wrapSender(base,material,address)
  if wrapped=.nil then do; base~close; return .nil; end
  return wrapped

/* Assembly helper demonstrates how a family is installed without teaching the
 * application anything about TLS internals.
 */
::class TLSFamilyInstaller public
::method install class
  use strict arg socketProvider, baseBinding, tlsEngine, securityMaterials
  socketProvider~registerBinding(.SocketTransportKind~TLS,.TLSSocketBinding~new(baseBinding,tlsEngine,securityMaterials))
  return socketProvider
::requires "SocketProvider.cls"
