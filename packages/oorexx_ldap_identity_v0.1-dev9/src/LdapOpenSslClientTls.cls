/* LdapOpenSslClientTls.cls
 * OpenSSL/Foreign Runtime client provider for LDAP StartTLS.
 *
 * The mechanics are deliberately aligned with the qualified API Client
 * OpenSSL memory-BIO path: RxSock owns the TCP socket, OpenSSL owns TLS,
 * peer verification is enabled by default, and SSL_set1_host binds the
 * certificate identity to the LDAP host name.
 */

::class LdapClientTlsConfig public
::attribute bridgeDirectory
::attribute caFile
::attribute verifyPeer
::attribute readChunkSize
::attribute readTimeout
::attribute writeTimeout
::method init
  expose bridgeDirectory caFile verifyPeer readChunkSize readTimeout writeTimeout
  bridgeDirectory="bridge"; caFile=""; verifyPeer=.true
  readChunkSize=16384; readTimeout=15; writeTimeout=15
::method validate
  expose bridgeDirectory verifyPeer readChunkSize readTimeout writeTimeout
  if bridgeDirectory="" then raise syntax 88.900 array("LDAP client TLS bridgeDirectory required")
  if verifyPeer<>.true & verifyPeer<>.false then raise syntax 88.900 array("verifyPeer must be logical")
  if readChunkSize<1024 | readChunkSize>1048576 then raise syntax 88.900 array("LDAP client TLS readChunkSize out of range")
  if readTimeout<=0 | writeTimeout<=0 then raise syntax 88.900 array("LDAP client TLS timeouts must be positive")
  return self

::class LdapClientTlsContext public
::attribute providerPath get
::attribute opensslVersion get
::attribute tlsPolicy get
::attribute closed get
::method init
  expose config tls bio err method ctx providerPath opensslVersion tlsPolicy closed gate
  use strict arg configArg
  config=configArg; config~validate
  gate=.LdapTlsNativeGate~new
  bridge=config~bridgeDirectory
  tls=.LdapTlsForeignLibrary~new(.foreign~load(bridge||"/openssl_tls_client.bridge.json"),gate)
  bio=.LdapTlsForeignLibrary~new(.foreign~load(bridge||"/openssl_bio.bridge.json"),gate)
  err=.LdapTlsForeignLibrary~new(.foreign~load(bridge||"/openssl_crypto_error.bridge.json"),gate)
  providerPath=tls~providerPath; opensslVersion=err~openssl_version(0); closed=.false
  if tls~threadingMode<>"thread-safe" | bio~threadingMode<>"thread-safe" | err~threadingMode<>"thread-safe" then raise syntax 88.900 array("OpenSSL Foreign Runtime bridges must be thread-safe")
  method=tls~tls_client_method
  if method==.nil then raise syntax 88.900 array("TLS_client_method returned null")
  ctx=tls~ctx_new(method)
  if ctx==.nil then raise syntax 88.900 array("SSL_CTX_new returned null",self~errorText)
  if tls~ctx_ctrl(ctx,123,771,.nil)<>1 then raise syntax 88.900 array("unable to set TLS 1.2 minimum",self~errorText)
  tlsPolicy="TLS1.2_MINIMUM"
  if config~verifyPeer then do
    if config~caFile<>"" then do
      if tls~ctx_load_verify_file(ctx,config~caFile)<>1 then raise syntax 88.900 array("unable to load LDAP TLS CA file",config~caFile,self~errorText)
    end
    else do
      if tls~ctx_set_default_verify_paths(ctx)<>1 then raise syntax 88.900 array("unable to load system trust store",self~errorText)
    end
    ignored=tls~ctx_set_verify(ctx,1,.nil)
  end
  else ignored=tls~ctx_set_verify(ctx,0,.nil)
::method newSession
  expose config closed
  use strict arg socket, host
  if closed then raise syntax 88.900 array("LDAP client TLS context closed")
  return .LdapClientTlsSession~new(self,socket,host,config)
::method tlsLibrary; expose tls; return tls
::method bioLibrary; expose bio; return bio
::method sslContext; expose ctx; return ctx
::method errorText
  expose err
  parts=.array~new
  do forever
    code=err~err_get_error; if code=0 then leave
    reason=err~err_reason_error_string(code); if reason==.nil then reason="OpenSSL error "||code
    parts~append(reason)
  end
  if parts~items=0 then return "no OpenSSL error detail"
  out=""; do i=1 to parts~items; if i>1 then out||="; "; out||=parts[i]; end
  return out
::method close
  expose tls bio err method ctx closed
  if closed then return
  closed=.true
  if ctx<>.nil then do; tls~closeObject(ctx); ctx=.nil; end
  if method<>.nil then do; tls~closeObject(method); method=.nil; end
  if tls<>.nil then do; tls~close; tls=.nil; end
  if bio<>.nil then do; bio~close; bio=.nil; end
  if err<>.nil then do; err~close; err=.nil; end
::method uninit; self~close

::class LdapClientTlsSession public
::attribute protocol get
::attribute cipher get
::attribute lastError get
::method init
  expose context tls bio ssl socket rbio wbio buffer wireBuffer bufferSize host protocol cipher lastError closed config
  use strict arg contextArg,socketArg,hostArg,configArg
  context=contextArg; socket=socketArg; host=hostArg~string; config=configArg; bufferSize=config~readChunkSize
  tls=context~tlsLibrary; bio=context~bioLibrary; protocol=""; cipher=""; lastError=""; closed=.false
  ssl=tls~ssl_new(context~sslContext)
  if ssl==.nil then raise syntax 88.900 array("SSL_new returned null",context~errorText)
  memMethod=bio~bio_s_mem
  if memMethod==.nil then raise syntax 88.900 array("BIO_s_mem returned null",context~errorText)
  rbio=bio~bio_new(memMethod); wbio=bio~bio_new(memMethod); bio~closeObject(memMethod)
  if rbio==.nil then raise syntax 88.900 array("LDAP client TLS memory BIO allocation failed",context~errorText)
  if wbio==.nil then raise syntax 88.900 array("LDAP client TLS memory BIO allocation failed",context~errorText)
  tls~ssl_set0_rbio(ssl,rbio); tls~ssl_set0_wbio(ssl,wbio)
  tls~ssl_set_connect_state(ssl)
  if config~verifyPeer then if tls~ssl_set1_host(ssl,host)<>1 then raise syntax 88.900 array("SSL_set1_host failed",host,context~errorText)
  /* SSL_CTRL_SET_TLSEXT_HOSTNAME=55, TLSEXT_NAMETYPE_host_name=0. */
  if tls~ssl_ctrl(ssl,55,0,host)<=0 then raise syntax 88.900 array("unable to configure TLS SNI",host,context~errorText)
  buffer=.foreign~buffer(bufferSize); wireBuffer=.foreign~buffer(bufferSize)
::method waitReady private
  expose socket lastError
  use strict arg errorCode,timeoutSeconds
  reads=.array~new; writes=.array~new; excepts=.array~of(socket)
  if errorCode=2 then reads~append(socket)
  else if errorCode=3 then writes~append(socket)
  else return .false
  rc=socket~select(reads,writes,excepts,timeoutSeconds)
  if rc==.nil then do; lastError="socket select failed errno="||socket~errno; return .false; end
  if rc=0 then do; lastError="socket readiness timeout"; return .false; end
  return .true
::method receiveEncrypted private
  expose socket bio rbio bufferSize lastError
  use strict arg timeoutSeconds
  if \self~waitReady(2,timeoutSeconds) then return "error"
  chunk=socket~recv(bufferSize)
  if chunk==.nil then return "retry"
  if chunk="" then return "closed"
  rc=bio~bio_write(rbio,chunk,chunk~length)
  if rc<>chunk~length then do; lastError="memory BIO input short write"; return "error"; end
  return "data"
::method sendRaw private
  expose socket lastError
  use strict arg data,timeoutSeconds
  offset=1
  do while offset<=data~length
    rc=socket~send(data~substr(offset))
    if rc>0 then do; offset+=rc; iterate; end
    if rc=0 then do; lastError="socket send returned zero"; return .false; end
    if \self~waitReady(3,timeoutSeconds) then return .false
  end
  return .true
::method drainOutput private
  expose bio wbio wireBuffer bufferSize config
  do forever
    rc=bio~bio_read(wbio,wireBuffer,bufferSize)
    if rc<=0 then return .true
    if \self~sendRaw(wireBuffer~bytes~substr(1,rc),config~writeTimeout) then return .false
  end
::method handshake
  expose context tls ssl protocol cipher lastError config
  call time "R"
  do attempt=1 to 100
    step=tls~sslStep("ssl_do_handshake",.array~of(ssl),ssl); rc=step[1]; ec=step[2]
    if \self~drainOutput then return .false
    if rc=1 then do
      if config~verifyPeer then do
        verify=tls~ssl_get_verify_result(ssl)
        if verify<>0 then do; lastError="certificate verification failed code="||verify; return .false; end
      end
      protocol=tls~ssl_get_version(ssl); c=tls~ssl_get_current_cipher(ssl)
      if c<>.nil then do; cipher=tls~ssl_cipher_get_name(c); tls~closeObject(c); end
      return .true
    end
    if ec=2 | ec=3 then do
      remaining=config~readTimeout-time("E")
      if remaining<=0 then do; lastError="TLS handshake timeout"; return .false; end
      if ec=2 then do
        feed=self~receiveEncrypted(remaining)
        if feed="data" | feed="retry" then iterate
        if feed="closed" then lastError="TLS peer closed during handshake"
        return .false
      end
      iterate
    end
    lastError="SSL_do_handshake rc="||rc||" error="||ec||" "||context~errorText
    return .false
  end
  lastError="TLS handshake retry limit exhausted"; return .false
::method read
  expose context tls ssl buffer bufferSize lastError config
  use strict arg maximum=0
  n=bufferSize; if maximum>0 & maximum<n then n=maximum
  do attempt=1 to 100
    step=tls~sslStep("ssl_read",.array~of(ssl,buffer,n),ssl); rc=step[1]; ec=step[2]
    if \self~drainOutput then return .nil
    if rc>0 then return buffer~bytes~substr(1,rc)
    if rc=0 & (ec=0 | ec=6) then return ""
    if ec=6 then return ""
    if ec=2 then do
      feed=self~receiveEncrypted(config~readTimeout)
      if feed="data" | feed="retry" then iterate
      if feed="closed" then return ""
      return .nil
    end
    if ec=3 then iterate
    lastError="SSL_read error="||ec||" "||context~errorText; return .nil
  end
  lastError="SSL_read retry limit exhausted"; return .nil
::method writeAll
  expose context tls ssl lastError config
  use strict arg data
  offset=1
  do while offset<=data~length
    n=data~length-offset+1; if n>16384 then n=16384
    chunk=data~substr(offset,n); sent=.false
    do attempt=1 to 100
      step=tls~sslStep("ssl_write",.array~of(ssl,chunk,n),ssl); rc=step[1]; ec=step[2]
      if \self~drainOutput then return .false
      if rc>0 then do; offset+=rc; sent=.true; leave; end
      if ec=2 then do
        feed=self~receiveEncrypted(config~readTimeout)
        if feed="data" | feed="retry" then iterate
        return .false
      end
      if ec=3 then iterate
      lastError="SSL_write error="||ec||" "||context~errorText; return .false
    end
    if \sent then return .false
  end
  return self~drainOutput
::method close
  expose tls bio ssl rbio wbio buffer wireBuffer closed protocol
  if closed then return
  closed=.true
  if ssl<>.nil then do
    if protocol<>"" then do; ignored=tls~ssl_shutdown(ssl); ignored=self~drainOutput; end
    if rbio<>.nil then do; bio~closeObject(rbio); rbio=.nil; end
    if wbio<>.nil then do; bio~closeObject(wbio); wbio=.nil; end
    tls~closeObject(ssl); ssl=.nil
  end
  if buffer<>.nil then do; if \buffer~closed then buffer~close; buffer=.nil; end
  if wireBuffer<>.nil then do; if \wireBuffer~closed then wireBuffer~close; wireBuffer=.nil; end
::method uninit; self~close

::class OpenSslLdapClientTlsProvider subclass LdapTlsProvider public
::attribute context get
::method init
  expose context
  use strict arg config
  context=.LdapClientTlsContext~new(config)
::method available; return .true
::method upgradeClient
  expose context
  use strict arg socket,host
  signal on syntax name failed
  session=context~newSession(socket,host)
  if \session~handshake then do; detail=session~lastError; session~close; return .DirectoryResult~failure("TLS_HANDSHAKE_FAILED",detail); end
  return .DirectoryResult~success(session)
failed:
  return .DirectoryResult~failure("TLS_PROVIDER_FAILED",condition("D"))
::method capabilities
  expose context
  d=.directory~new; d["available"]=.true; d["api"]=.LdapTlsBuild~API_VERSION; d["provider"]="OpenSSL/Foreign Runtime client"; d["providerPath"]=context~providerPath; d["opensslVersion"]=context~opensslVersion; d["tlsPolicy"]=context~tlsPolicy; return d
::method close
  expose context
  if context<>.nil then do; context~close; context=.nil; end

::requires "src/LdapOpenSslCommon.cls"
::requires "src/LdapTls.cls"
