/* Provider-neutral secure socket layer for ooRexx protocol servers.
 * API secure.socket/0.1.  Protocols own protocol semantics; this layer owns
 * transport confidentiality/integrity upgrade and transport evidence only.
 */
::class SecureSocketBuild public
::constant RELEASE "0.1-dev2"
::constant API_VERSION "secure.socket/0.1"

::class SecureSocketResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::method init
  expose ok code value detail
  use strict arg okArg, codeArg="OK", valueArg=.nil, detailArg=""
  ok=okArg; code=codeArg; value=valueArg; detail=detailArg
::method success class
  use strict arg value=.nil, code="OK"
  return self~new(.true,code,value,"")
::method failure class
  use strict arg code, detail=""
  return self~new(.false,code,.nil,detail)

::class SecureSocketProvider public
::method available; return .false
::method upgradeServer
  use strict arg socket
  return .SecureSocketResult~failure("TLS_PROVIDER_UNAVAILABLE")
::method upgradeClient
  use strict arg socket,host
  return .SecureSocketResult~failure("TLS_PROVIDER_UNAVAILABLE")
::method capabilities
  d=.directory~new; d["api"]=.SecureSocketBuild~API_VERSION; d["available"]=.false; return d
::method close; return

::class SecureSocketTransport public
::method init
  expose socket session
  use strict arg socketArg,sessionArg
  socket=socketArg; session=sessionArg
::method recv
  expose session
  use strict arg maximum=16384
  return session~read(maximum)
::method send
  expose session
  use strict arg bytes
  if session~writeAll(bytes) then return bytes~length
  return 0
::method close
  expose session socket
  if session<>.nil then do; session~close; session=.nil; end
  if socket<>.nil then do; socket~close; socket=.nil; end
::method hasMethod
  use strict arg name
  return self~class~method(name) <> .nil
