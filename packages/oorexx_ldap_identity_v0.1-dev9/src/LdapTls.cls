/* LdapTls.cls
 * Provider-neutral LDAP TLS/StartTLS seam.
 *
 * This file deliberately has no Foreign Runtime/OpenSSL dependency.  An LDAP
 * server can therefore support plaintext LDAP and other TLS providers without
 * loading native TLS code.  Concrete providers live behind LdapTlsProvider.
 */

::class LdapTlsBuild public
::constant API_VERSION "ldap.tls/0.1"
::constant STARTTLS_OID "1.3.6.1.4.1.1466.20037"

::class LdapTlsProvider public
::method available
  return .false
::method upgradeServer
  use strict arg socket
  return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
::method upgradeClient
  use strict arg socket, host
  return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
::method capabilities
  d=.directory~new; d["available"]=.false; d["api"]=.LdapTlsBuild~API_VERSION; return d
::method close
  return

::class LdapTlsTransport public
::method init
  expose socket session
  use strict arg socketArg,sessionArg
  socket=socketArg; session=sessionArg
::method ldapRecv
  expose session
  use strict arg maximum
  return session~read(maximum)
::method ldapSend
  expose session
  use strict arg bytes
  if session~writeAll(bytes) then return bytes~length
  return 0
::method ldapClose
  expose session socket
  if session<>.nil then do; session~close; session=.nil; end
  if socket<>.nil then do; socket~close; socket=.nil; end

::requires "src/IdentityDirectory.cls"
