/* ooRexx HTTPS Server v0.4.4
 * Native ooRexx socket / HTTP implementation with TLS through
 * ooRexx Foreign Runtime v0.17.1 -> system OpenSSL libssl.
 * Request interception remains an ooRexx application boundary above transport.
 */

::class HttpsServerConfig public
::attribute bindAddress
::attribute port
::attribute certificateFile
::attribute privateKeyFile
::attribute clientCAFile
::attribute requireClientCertificate
::attribute backlog
::attribute maxConnections
::attribute readTimeout
::attribute writeTimeout
::attribute maxHeaderBytes
::attribute maxHeaderCount
::attribute maxBodyBytes
::attribute maxRequestsPerConnection
::attribute readChunkSize
::attribute tls12CipherList
::attribute tls13CipherSuites
::attribute bridgeDirectory
::attribute accessLog
::attribute nativeTlsConcurrency
::attribute connectionWorkers
::attribute maxPendingConnections

::method init
  expose bindAddress port certificateFile privateKeyFile clientCAFile requireClientCertificate backlog maxConnections readTimeout writeTimeout maxHeaderBytes maxHeaderCount maxBodyBytes maxRequestsPerConnection readChunkSize tls12CipherList tls13CipherSuites bridgeDirectory accessLog nativeTlsConcurrency connectionWorkers maxPendingConnections
  bindAddress='127.0.0.1'
  port=8443
  certificateFile=''
  privateKeyFile=''
  clientCAFile=''
  requireClientCertificate=.false
  backlog=64
  maxConnections=128
  readTimeout=15
  writeTimeout=15
  maxHeaderBytes=32768
  maxHeaderCount=100
  maxBodyBytes=1048576
  maxRequestsPerConnection=100
  readChunkSize=16384
  tls12CipherList='ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256'
  tls13CipherSuites='TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256'
  bridgeDirectory=''
  accessLog=.true
  nativeTlsConcurrency=1
  connectionWorkers=16
  maxPendingConnections=64

::method copy
  expose bindAddress port certificateFile privateKeyFile clientCAFile requireClientCertificate backlog maxConnections readTimeout writeTimeout maxHeaderBytes maxHeaderCount maxBodyBytes maxRequestsPerConnection readChunkSize tls12CipherList tls13CipherSuites bridgeDirectory accessLog nativeTlsConcurrency connectionWorkers maxPendingConnections
  c=.HttpsServerConfig~new
  c~bindAddress=bindAddress
  c~port=port
  c~certificateFile=certificateFile
  c~privateKeyFile=privateKeyFile
  c~clientCAFile=clientCAFile
  c~requireClientCertificate=requireClientCertificate
  c~backlog=backlog
  c~maxConnections=maxConnections
  c~readTimeout=readTimeout
  c~writeTimeout=writeTimeout
  c~maxHeaderBytes=maxHeaderBytes
  c~maxHeaderCount=maxHeaderCount
  c~maxBodyBytes=maxBodyBytes
  c~maxRequestsPerConnection=maxRequestsPerConnection
  c~readChunkSize=readChunkSize
  c~tls12CipherList=tls12CipherList
  c~tls13CipherSuites=tls13CipherSuites
  c~bridgeDirectory=bridgeDirectory
  c~accessLog=accessLog
  c~nativeTlsConcurrency=nativeTlsConcurrency
  c~connectionWorkers=connectionWorkers
  c~maxPendingConnections=maxPendingConnections
  return c

::method validate
  expose bindAddress port certificateFile privateKeyFile backlog maxConnections readTimeout writeTimeout maxHeaderBytes maxHeaderCount maxBodyBytes maxRequestsPerConnection readChunkSize bridgeDirectory nativeTlsConcurrency connectionWorkers maxPendingConnections
  if certificateFile='' then raise syntax 40.900 array('HTTPS certificate file is required')
  if privateKeyFile='' then raise syntax 40.900 array('HTTPS private key file is required')
  if bridgeDirectory='' then raise syntax 40.900 array('OpenSSL bridge directory is required')
  if port~datatype('W')=0 | port<0 | port>65535 then raise syntax 40.900 array('Invalid HTTPS port',port)
  if backlog~datatype('W')=0 | backlog<1 then raise syntax 40.900 array('Invalid listen backlog',backlog)
  if maxConnections~datatype('W')=0 | maxConnections<1 then raise syntax 40.900 array('Invalid maxConnections',maxConnections)
  if nativeTlsConcurrency~datatype('W')=0 | nativeTlsConcurrency<>1 then raise syntax 40.900 array('v0.4.4 memory-BIO transport requires nativeTlsConcurrency=1',nativeTlsConcurrency)
  if connectionWorkers~datatype('W')=0 | connectionWorkers<1 | connectionWorkers>64 then raise syntax 40.900 array('Invalid connectionWorkers',connectionWorkers)
  if maxPendingConnections~datatype('W')=0 | maxPendingConnections<connectionWorkers then raise syntax 40.900 array('maxPendingConnections must be at least connectionWorkers',maxPendingConnections,connectionWorkers)
  if readTimeout~datatype('W')=0 | readTimeout<1 then raise syntax 40.900 array('Invalid readTimeout',readTimeout)
  if writeTimeout~datatype('W')=0 | writeTimeout<1 then raise syntax 40.900 array('Invalid writeTimeout',writeTimeout)
  if maxHeaderBytes~datatype('W')=0 | maxHeaderBytes<1024 then raise syntax 40.900 array('Invalid maxHeaderBytes',maxHeaderBytes)
  if maxHeaderCount~datatype('W')=0 | maxHeaderCount<1 then raise syntax 40.900 array('Invalid maxHeaderCount',maxHeaderCount)
  if maxBodyBytes~datatype('W')=0 | maxBodyBytes<0 then raise syntax 40.900 array('Invalid maxBodyBytes',maxBodyBytes)
  if maxRequestsPerConnection~datatype('W')=0 | maxRequestsPerConnection<1 then raise syntax 40.900 array('Invalid maxRequestsPerConnection',maxRequestsPerConnection)
  if readChunkSize~datatype('W')=0 | readChunkSize<1024 | readChunkSize>1048576 then raise syntax 40.900 array('Invalid readChunkSize',readChunkSize)
  return .true


::class HttpRequest public
::attribute method get
::attribute target get
::attribute path get
::attribute query get
::attribute version get
::attribute headers get
::attribute body get
::attribute keepAlive get
::attribute peerAddress get
::attribute tlsProtocol get
::attribute tlsCipher get
::attribute tlsGeneration get
::attribute context get

::method init
  expose method target path query version headers body keepAlive peerAddress tlsProtocol tlsCipher tlsGeneration context
  use strict arg method, target, path, query, version, headers, body, keepAlive, peerAddress='', tlsProtocol='', tlsCipher='', tlsGeneration=0
  context=.nil

::method attachContext
  expose context
  use strict arg value
  if context<>.nil then raise syntax 40.900 array('HTTP request context is already attached')
  if value==.nil | \value~isA(.HttpExchangeContext) then raise syntax 40.900 array('Invalid HTTP exchange context')
  context=value
  return self

::method header
  expose headers
  use strict arg name, defaultValue=''
  key=name~lower
  if headers~hasIndex(key) then return headers[key]
  return defaultValue


::class HttpExchangeContext public
::attribute requestId get
::attribute peerAddress get
::attribute tlsProtocol get
::attribute tlsCipher get
::attribute tlsGeneration get

::method init
  expose requestId peerAddress tlsProtocol tlsCipher tlsGeneration values
  use strict arg requestId, request
  peerAddress=request~peerAddress
  tlsProtocol=request~tlsProtocol
  tlsCipher=request~tlsCipher
  tlsGeneration=request~tlsGeneration
  values=.directory~new

::method put
  expose values
  use strict arg name, value
  if name='' then raise syntax 40.900 array('HTTP exchange context attribute name is required')
  values[name]=value
  return self

::method get
  expose values
  use strict arg name, defaultValue=.nil
  if values~hasIndex(name) then return values[name]
  return defaultValue

::method has
  expose values
  use strict arg name
  return values~hasIndex(name)

::method remove
  expose values
  use strict arg name
  if values~hasIndex(name) then values~remove(name)
  return self


::class HttpInterceptorBinding
::attribute target get
::attribute beforeMethod get
::attribute afterMethod get

::method init
  expose target beforeMethod afterMethod
  use strict arg target, beforeMethod='beforeRequest', afterMethod='afterResponse'
  if target==.nil then raise syntax 40.900 array('HTTP interceptor target is required')
  if beforeMethod='' & afterMethod='' then raise syntax 40.900 array('HTTP interceptor must define a before or after method')

::method before unguarded
  expose target beforeMethod
  use strict arg request, context
  if beforeMethod='' then return .nil
  return target~sendWith(beforeMethod,.array~of(request,context))

::method after unguarded
  expose target afterMethod
  use strict arg request, response, context
  if afterMethod='' then return .nil
  return target~sendWith(afterMethod,.array~of(request,response,context))


::class HttpResponse public
::attribute status get
::attribute headers get
::attribute body get

::method init
  expose status headers body
  use strict arg status=200, body='', contentType='text/plain; charset=utf-8'
  headers=.directory~new
  self~header('Content-Type',contentType)

::method header
  expose headers
  use strict arg name, value
  headers[name]=value
  return self

::method text class
  use strict arg text='', status=200, contentType='text/plain; charset=utf-8'
  return .HttpResponse~new(status,text,contentType)

::method json class
  use strict arg jsonText='{}', status=200
  return .HttpResponse~new(status,jsonText,'application/json; charset=utf-8')

::method empty class
  use strict arg status=204
  return .HttpResponse~new(status,'','application/octet-stream')


::class HttpUtil public
::method reason class
  use strict arg status
  select
    when status=100 then return 'Continue'
    when status=200 then return 'OK'
    when status=201 then return 'Created'
    when status=202 then return 'Accepted'
    when status=204 then return 'No Content'
    when status=301 then return 'Moved Permanently'
    when status=302 then return 'Found'
    when status=304 then return 'Not Modified'
    when status=400 then return 'Bad Request'
    when status=401 then return 'Unauthorized'
    when status=403 then return 'Forbidden'
    when status=404 then return 'Not Found'
    when status=405 then return 'Method Not Allowed'
    when status=408 then return 'Request Timeout'
    when status=409 then return 'Conflict'
    when status=411 then return 'Length Required'
    when status=413 then return 'Content Too Large'
    when status=414 then return 'URI Too Long'
    when status=417 then return 'Expectation Failed'
    when status=421 then return 'Misdirected Request'
    when status=431 then return 'Request Header Fields Too Large'
    when status=500 then return 'Internal Server Error'
    when status=501 then return 'Not Implemented'
    when status=503 then return 'Service Unavailable'
    when status=505 then return 'HTTP Version Not Supported'
    otherwise return 'Status'
  end

::method tokenValid class
  use strict arg text
  if text='' then return .false
  allowed="!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  return text~verify(allowed)=0

::method response class
  use strict arg status, message=''
  if message='' then message=self~reason(status)
  body=message||'0A'x
  return .HttpResponse~text(body,status)

::method lowerContainsToken class
  use strict arg value, wanted
  rest=value
  do while rest<>''
    p=rest~pos(',')
    if p=0 then do
      item=rest
      rest=''
    end
    else do
      item=rest~substr(1,p-1)
      rest=rest~substr(p+1)
    end
    if item~strip~lower=wanted~lower then return .true
  end
  return .false


::class TlsNativeLane
::method init
  expose owner
  use strict arg owner

/* Every lane is guarded. v0.4.4 server configuration requires exactly one
 * lane: OpenSSL work is serialized and memory-only; RxSock network waits occur
 * outside the lane. The small pool abstraction is retained for telemetry and
 * possible future requalification, not as a supported v0.4.4 concurrency knob. */
::method invoke
  expose owner
  use strict arg library, name, args
  owner~entered
  signal on syntax name invokeFailure
  value=library~invokeArray(name,args)
  owner~left
  return value
invokeFailure:
  owner~left
  raise propagate

::method sslStep
  expose owner
  use strict arg library, name, args, ssl
  owner~entered
  signal on syntax name sslStepFailure
  rc=library~invokeArray(name,args)
  ec=0
  if rc<=0 then ec=library~invokeArray('ssl_get_error',.array~of(ssl,rc))
  owner~left
  return .array~of(rc,ec)
sslStepFailure:
  owner~left
  raise propagate

::method closeObject
  expose owner
  use strict arg object
  owner~entered
  signal on syntax name closeObjectFailure
  if object<>.nil then if \object~closed then object~close
  owner~left
  return .nil
closeObjectFailure:
  owner~left
  raise propagate

::method closeLibrary
  expose owner
  use strict arg library
  owner~entered
  signal on syntax name closeLibraryFailure
  if library<>.nil then library~close
  owner~left
  return .nil
closeLibraryFailure:
  owner~left
  raise propagate


::class TlsNativeGate public
::attribute invocationCount get
::attribute policy get
::attribute laneCount get
::attribute maxConcurrent get

::method init
  expose invocationCount policy laneCount lanes cursor active maxConcurrent
  use strict arg requestedLanes=1
  laneCount=requestedLanes
  invocationCount=0
  policy='bounded-'laneCount'-nonblocking'
  lanes=.array~new
  do i=1 to laneCount
    lanes~append(.TlsNativeLane~new(self))
  end
  cursor=1
  active=0
  maxConcurrent=0

/* Lane selection is a tiny guarded operation. The v0.4.4 server admits one
 * lane only, guaranteeing that Foreign Runtime/OpenSSL calls never overlap. */
::method nextLane
  expose lanes cursor laneCount invocationCount
  lane=lanes[cursor]
  cursor=cursor+1
  if cursor>laneCount then cursor=1
  invocationCount=invocationCount+1
  return lane

::method entered
  expose active maxConcurrent
  active=active+1
  if active>maxConcurrent then maxConcurrent=active

::method left
  expose active
  if active>0 then active=active-1

::method invoke unguarded
  use strict arg library, name, args
  lane=self~nextLane
  return lane~invoke(library,name,args)

::method sslStep unguarded
  use strict arg library, name, args, ssl
  lane=self~nextLane
  return lane~sslStep(library,name,args,ssl)

::method closeObject unguarded
  use strict arg object
  lane=self~nextLane
  return lane~closeObject(object)

::method closeLibrary unguarded
  use strict arg library
  lane=self~nextLane
  return lane~closeLibrary(library)


::class TlsForeignLibrary public
::method init
  expose library gate
  use strict arg library, gate

::method unknown unguarded
  expose library gate
  use strict arg name, args
  return gate~invoke(library,name,args)

::method sslStep unguarded
  expose library gate
  use strict arg name, args, ssl
  return gate~sslStep(library,name,args,ssl)

::method closeObject unguarded
  expose gate
  use strict arg object
  return gate~closeObject(object)

::method providerPath unguarded
  expose library
  return library~providerPath

::method threadingMode unguarded
  expose library
  return library~threadingMode

::method close unguarded
  expose library gate
  if library<>.nil then do
    gate~closeLibrary(library)
    library=.nil
  end


::class TlsContext public
::attribute providerPath get
::attribute opensslVersion get
::attribute foreignRuntimeVersion get
::attribute foreignDispatcher get
::attribute foreignThreadingMode get
::attribute tlsPolicy get
::attribute nativeConcurrencyPolicy get
::attribute generation get
::attribute activePins get
::attribute retired get
::attribute closed get

::method init
  expose config tls bio err method ctx providerPath opensslVersion foreignRuntimeVersion foreignDispatcher foreignThreadingMode tlsPolicy nativeConcurrencyPolicy generation activePins retired closed nativeGate
  use strict arg config, generation=1, nativeGate=.nil
  if nativeGate==.nil then nativeGate=.TlsNativeGate~new
  tls=.nil
  bio=.nil
  err=.nil
  method=.nil
  ctx=.nil
  bridge=config~bridgeDirectory
  tls=.TlsForeignLibrary~new(.foreign~load(bridge'/openssl_tls.bridge.json'),nativeGate)
  bio=.TlsForeignLibrary~new(.foreign~load(bridge'/openssl_bio.bridge.json'),nativeGate)
  err=.TlsForeignLibrary~new(.foreign~load(bridge'/openssl_crypto_error.bridge.json'),nativeGate)
  providerPath=tls~providerPath
  opensslVersion=err~openssl_version(0)
  runtime=.foreign~runtimeInfo
  foreignRuntimeVersion=runtime~runtimeVersion
  foreignDispatcher=runtime~nativeDispatcher
  foreignThreadingMode=tls~threadingMode
  nativeConcurrencyPolicy=nativeGate~policy
  if foreignThreadingMode<>'thread-safe' then raise syntax 40.900 array('OpenSSL Foreign Runtime provider must be declared thread-safe',foreignThreadingMode)
  if bio~threadingMode<>'thread-safe' | err~threadingMode<>'thread-safe' then raise syntax 40.900 array('All OpenSSL bridge libraries must be declared thread-safe')
  activePins=0
  retired=.false
  closed=.false

  method=tls~tls_server_method
  if method==.nil then raise syntax 40.900 array('TLS_server_method returned null')
  ctx=tls~ctx_new(method)
  if ctx==.nil then raise syntax 40.900 array('SSL_CTX_new returned null',self~errorText)

  /* Prefer OpenSSL's native minimum-protocol control when the Foreign
   * Runtime has its libffi dynamic-arity dispatcher.  Keep the proven
   * exported-option path as the explicit <=3-argument portability fallback. */
  if runtime~maxArity=0 then do
    /* SSL_CTRL_SET_MIN_PROTO_VERSION=123, TLS1_2_VERSION=0x0303=771. */
    if tls~ctx_ctrl(ctx,123,771,.nil)<>1 then raise syntax 40.900 array('Unable to set TLS 1.2 minimum protocol',self~errorText)
    ignored=tls~ctx_set_options(ctx,1073741824) /* SSL_OP_NO_RENEGOTIATION */
    tlsPolicy='min-proto-control'
  end
  else do
    ignored=tls~ctx_set_options(ctx,1409286144) /* NO_TLSv1 + NO_TLSv1_1 + NO_RENEGOTIATION */
    tlsPolicy='options-fallback'
  end

  if config~tls12CipherList<>'' then do
    if tls~ctx_set_cipher_list(ctx,config~tls12CipherList)<>1 then raise syntax 40.900 array('Unable to configure TLS 1.2 cipher list',self~errorText)
  end
  if config~tls13CipherSuites<>'' then do
    if tls~ctx_set_ciphersuites(ctx,config~tls13CipherSuites)<>1 then raise syntax 40.900 array('Unable to configure TLS 1.3 cipher suites',self~errorText)
  end

  if tls~ctx_use_certificate_chain_file(ctx,config~certificateFile)<>1 then raise syntax 40.900 array('Unable to load certificate chain',config~certificateFile,self~errorText)
  if tls~ctx_use_private_key_file(ctx,config~privateKeyFile,1)<>1 then raise syntax 40.900 array('Unable to load private key',config~privateKeyFile,self~errorText)
  if tls~ctx_check_private_key(ctx)<>1 then raise syntax 40.900 array('Certificate and private key do not match',self~errorText)

  if config~clientCAFile<>'' then do
    if tls~ctx_load_verify_file(ctx,config~clientCAFile)<>1 then raise syntax 40.900 array('Unable to load client CA file',config~clientCAFile,self~errorText)
    verifyMode=1
    if config~requireClientCertificate then verifyMode=3
    ignored=tls~ctx_set_verify(ctx,verifyMode,.nil)
  end
  else if config~requireClientCertificate then raise syntax 40.900 array('requireClientCertificate needs clientCAFile')

::method tlsLibrary
  expose tls
  return tls

::method bioLibrary
  expose bio
  return bio

::method sslContext
  expose ctx
  return ctx

::method pin
  expose activePins retired closed
  if retired | closed then return .false
  activePins=activePins+1
  return .true

::method release
  expose activePins retired
  if activePins>0 then activePins=activePins-1
  if retired & activePins=0 then self~closeNow
  return activePins

::method retire
  expose retired activePins
  retired=.true
  if activePins=0 then self~closeNow
  return activePins

::method newSession
  expose closed
  use strict arg socket, config
  if closed then raise syntax 40.900 array('TLS context is closed')
  return .TlsSession~new(self,socket,config~readChunkSize,config~readTimeout,config~writeTimeout)

::method errorText
  expose err
  if err==.nil then return 'OpenSSL error library unavailable'
  parts=.array~new
  do forever
    code=err~err_get_error
    if code=0 then leave
    reason=err~err_reason_error_string(code)
    if reason==.nil then reason='OpenSSL error' code
    parts~append(reason)
  end
  if parts~items=0 then return 'no OpenSSL error detail'
  out=''
  do i=1 to parts~items
    if i>1 then out=out'; '
    out=out||parts[i]
  end
  return out

::method closeForeignObject
  expose tls
  use strict arg object
  return tls~closeObject(object)

::method close
  return self~retire

::method closeNow private
  expose tls bio err method ctx closed
  if closed then return
  closed=.true
  if ctx<>.nil then do
    tls~closeObject(ctx)
    ctx=.nil
  end
  if method<>.nil then do
    tls~closeObject(method)
    method=.nil
  end
  if tls<>.nil then do; tls~close; tls=.nil; end
  if bio<>.nil then do; bio~close; bio=.nil; end
  if err<>.nil then do; err~close; err=.nil; end

::method uninit
  self~retire


::class TlsSession public
::attribute protocol get
::attribute cipher get
::attribute lastError get
::attribute handshakeRetries get
::attribute contextGeneration get

::method init
  expose tlsContext tls bio ssl socket rbio wbio buffer wireBuffer bufferSize protocol cipher lastError handshakeRetries contextGeneration closed readTimeout writeTimeout
  use strict arg tlsContext, socket, bufferSize, readTimeout=15, writeTimeout=15
  contextGeneration=tlsContext~generation
  tls=tlsContext~tlsLibrary
  bio=tlsContext~bioLibrary
  ssl=tls~ssl_new(tlsContext~sslContext)
  if ssl==.nil then raise syntax 40.900 array('SSL_new returned null',tlsContext~errorText)

  /* v0.4.4 deliberately uses OpenSSL memory BIOs. RxSock is the sole network
   * I/O owner; libssl never receives the accepted descriptor. This removes
   * socket readiness, EOF/reset handling, and peer latency from the native
   * Foreign Runtime/OpenSSL critical section. */
  memMethod=bio~bio_s_mem
  if memMethod==.nil then do
    tls~closeObject(ssl)
    raise syntax 40.900 array('BIO_s_mem returned null',tlsContext~errorText)
  end
  rbio=bio~bio_new(memMethod)
  if rbio==.nil then do
    bio~closeObject(memMethod)
    tls~closeObject(ssl)
    raise syntax 40.900 array('BIO_new(read memory BIO) failed',tlsContext~errorText)
  end
  wbio=bio~bio_new(memMethod)
  if wbio==.nil then do
    ignored=bio~bio_free(rbio)
    bio~closeObject(rbio)
    bio~closeObject(memMethod)
    tls~closeObject(ssl)
    raise syntax 40.900 array('BIO_new(write memory BIO) failed',tlsContext~errorText)
  end
  bio~closeObject(memMethod)

  tls~ssl_set0_rbio(ssl,rbio)
  tls~ssl_set0_wbio(ssl,wbio)
  /* SSL now owns both BIOs. Keep only borrowed Foreign Runtime wrappers so
   * BIO_read/BIO_write can address them; wrappers are closed before SSL_free. */
  tls~ssl_set_accept_state(ssl)

  buffer=.foreign~buffer(bufferSize)
  wireBuffer=.foreign~buffer(bufferSize)
  protocol=''
  cipher=''
  lastError=''
  handshakeRetries=0
  closed=.false

::method handshake
  expose tlsContext tls ssl protocol cipher lastError handshakeRetries readTimeout
  handshakeRetries=0
  call time 'R'
  do attempt=1 to 100
    step=tls~sslStep('ssl_do_handshake',.array~of(ssl),ssl)
    rc=step[1]
    ec=step[2]

    /* A handshake call may emit records even while asking for more input. */
    if \self~drainOutput then return .false

    if rc=1 then do
      protocol=tls~ssl_get_version(ssl)
      c=tls~ssl_get_current_cipher(ssl)
      if c<>.nil then do
        cipher=tls~ssl_cipher_get_name(c)
        tls~closeObject(c)
      end
      return .true
    end

    if ec=2 | ec=3 then do
      handshakeRetries=handshakeRetries+1
      remaining=readTimeout-time('E')
      if remaining<=0 then do
        lastError='TLS handshake timeout after 'readTimeout' seconds attempts='attempt' retries='handshakeRetries
        return .false
      end
      if ec=2 then do
        feed=self~receiveEncrypted(remaining)
        if feed='data' | feed='retry' then iterate
        if feed='closed' then do
          lastError='TLS peer closed during handshake attempts='attempt' retries='handshakeRetries
          return .false
        end
        return .false
      end
      /* With an unbounded memory BIO, WANT_WRITE is normally transient after
       * draining output. Re-enter SSL without waiting on the network. */
      iterate
    end

    detail=tlsContext~errorText
    state=tls~ssl_state_string_long(ssl)
    if state==.nil then state='state='tls~ssl_get_state(ssl)
    lastError='SSL_do_handshake rc='rc' error='self~errorName(ec)' state='state' attempts='attempt' retries='handshakeRetries' detail='detail
    return .false
  end
  lastError='TLS handshake retry limit exhausted'
  return .false

::method waitReady private
  expose socket lastError
  use strict arg errorCode, timeoutSeconds
  reads=.array~new
  writes=.array~new
  excepts=.array~of(socket)
  if errorCode=2 then reads~append(socket)
  else if errorCode=3 then writes~append(socket)
  else return .false
  rc=socket~select(reads,writes,excepts,timeoutSeconds)
  if rc==.nil then do
    lastError='socket select failed errno='socket~errno
    return .false
  end
  if rc=0 then do
    lastError='socket readiness timeout after 'timeoutSeconds' seconds'
    return .false
  end
  return .true

::method receiveEncrypted private
  expose socket bio rbio bufferSize lastError
  use strict arg timeoutSeconds
  if \self~waitReady(2,timeoutSeconds) then return 'error'
  chunk=socket~recv(bufferSize)
  if chunk==.nil then return 'retry'
  if chunk='' then return 'closed'
  rc=bio~bio_write(rbio,chunk,chunk~length)
  if rc<>chunk~length then do
    lastError='memory BIO input short write rc='rc' expected='chunk~length
    return 'error'
  end
  return 'data'

::method sendRaw private
  expose socket lastError
  use strict arg data, timeoutSeconds
  offset=1
  total=data~length
  do attempt=1 to 100 while offset<=total
    rc=socket~send(data~substr(offset))
    if rc>0 then do
      offset=offset+rc
      iterate
    end
    if rc=0 then do
      lastError='socket send returned zero'
      return .false
    end
    if \self~waitReady(3,timeoutSeconds) then return .false
  end
  if offset<=total then do
    lastError='socket send retry limit exhausted'
    return .false
  end
  return .true

::method drainOutput private
  expose bio wbio wireBuffer bufferSize lastError writeTimeout
  do forever
    rc=bio~bio_read(wbio,wireBuffer,bufferSize)
    if rc<=0 then return .true
    wire=wireBuffer~bytes~substr(1,rc)
    if \self~sendRaw(wire,writeTimeout) then return .false
  end

::method errorName private
  use strict arg code
  select
    when code=0 then return 'SSL_ERROR_NONE(0)'
    when code=1 then return 'SSL_ERROR_SSL(1)'
    when code=2 then return 'SSL_ERROR_WANT_READ(2)'
    when code=3 then return 'SSL_ERROR_WANT_WRITE(3)'
    when code=4 then return 'SSL_ERROR_WANT_X509_LOOKUP(4)'
    when code=5 then return 'SSL_ERROR_SYSCALL(5)'
    when code=6 then return 'SSL_ERROR_ZERO_RETURN(6)'
    when code=7 then return 'SSL_ERROR_WANT_CONNECT(7)'
    when code=8 then return 'SSL_ERROR_WANT_ACCEPT(8)'
    otherwise return 'SSL_ERROR_'code
  end

::method read
  expose tlsContext tls ssl buffer bufferSize lastError readTimeout
  use strict arg maximum=0
  n=bufferSize
  if maximum>0 & maximum<n then n=maximum
  do attempt=1 to 100
    step=tls~sslStep('ssl_read',.array~of(ssl,buffer,n),ssl)
    rc=step[1]
    ec=step[2]
    if \self~drainOutput then return .nil
    if rc>0 then return buffer~bytes~substr(1,rc)
    if rc=0 & (ec=0 | ec=6) then return ''
    if ec=6 then return ''
    if ec=2 then do
      feed=self~receiveEncrypted(readTimeout)
      if feed='data' | feed='retry' then iterate
      if feed='closed' then return ''
      return .nil
    end
    if ec=3 then iterate
    lastError='SSL_read error='self~errorName(ec)' 'tlsContext~errorText
    return .nil
  end
  lastError='SSL_read retry limit exhausted'
  return .nil

::method writeAll
  expose tlsContext tls ssl lastError writeTimeout readTimeout
  use strict arg data
  offset=1
  total=data~length
  do while offset<=total
    n=total-offset+1
    if n>16384 then n=16384
    chunk=data~substr(offset,n)
    sent=.false
    do attempt=1 to 100
      step=tls~sslStep('ssl_write',.array~of(ssl,chunk,n),ssl)
      rc=step[1]
      ec=step[2]
      if \self~drainOutput then return .false
      if rc>0 then do
        offset=offset+rc
        sent=.true
        leave
      end
      if ec=2 then do
        feed=self~receiveEncrypted(readTimeout)
        if feed='data' | feed='retry' then iterate
        if feed='closed' then lastError='TLS peer closed while write required input'
        return .false
      end
      if ec=3 then iterate
      lastError='SSL_write error='self~errorName(ec)' 'tlsContext~errorText
      return .false
    end
    if \sent then do
      lastError='SSL_write retry limit exhausted'
      return .false
    end
  end
  return self~drainOutput

::method close
  expose tls bio ssl rbio wbio buffer wireBuffer closed protocol
  if closed then return
  closed=.true
  if ssl<>.nil then do
    /* Do not run TLS shutdown for a connection that never completed a
     * handshake.  A hostile/incomplete peer is transport garbage, not a TLS
     * session that deserves close_notify work.  This keeps abort storms off
     * the cleanup hot path. */
    if protocol<>'' then do
      ignored=tls~ssl_shutdown(ssl)
      ignored=self~drainOutput
    end
    /* Borrowed BIO wrappers must disappear before SSL_free destroys BIOs. */
    if rbio<>.nil then do; bio~closeObject(rbio); rbio=.nil; end
    if wbio<>.nil then do; bio~closeObject(wbio); wbio=.nil; end
    tls~closeObject(ssl)
    ssl=.nil
  end
  if buffer<>.nil then do
    if \buffer~closed then buffer~close
    buffer=.nil
  end
  if wireBuffer<>.nil then do
    if \wireBuffer~closed then wireBuffer~close
    wireBuffer=.nil
  end

::method uninit
  self~close


::class HttpsConnectionQueue public
::attribute accepted get
::attribute rejected get
::attribute highWaterMark get
::attribute capacity get

::method init
  expose queue stopped accepted rejected highWaterMark capacity
  use strict arg capacity
  queue=.queue~new
  stopped=.false
  accepted=0
  rejected=0
  highWaterMark=0

/* Accepted sockets enter a bounded FIFO before any per-connection TLS work.
 * This is the admission boundary: an unauthenticated peer no longer earns a
 * fresh ooRexx activity merely by completing TCP accept(). */
::method add guarded
  expose queue stopped accepted rejected highWaterMark capacity
  use strict arg item
  if stopped then do
    rejected=rejected+1
    return .false
  end
  if queue~items>=capacity then do
    rejected=rejected+1
    return .false
  end
  queue~queue(item)
  accepted=accepted+1
  if queue~items>highWaterMark then highWaterMark=queue~items
  return .true

/* Non-blocking queue poll by design.  A worker sleeps briefly when empty
 * rather than parking forever in GUARD ON WHEN.  This matters operationally:
 * ooRexx HALT/TERM can then interrupt every worker activity, so a process does
 * not remain alive solely because queue waiters are parked on object guards. */
::method next guarded
  expose queue stopped
  if \queue~isEmpty then return queue~pull
  if stopped then return .false
  return .nil

::method stop guarded
  expose stopped
  stopped=.true

::method pendingCount guarded
  expose queue
  return queue~items


::class HttpsConnectionWorker public
::method init
  expose server workerId
  use strict arg server, workerId

::method run unguarded
  expose server workerId
  do forever
    job=server~nextAcceptedConnection
    if job==.false then leave
    if job==.nil then do
      call SysSleep .005
      iterate
    end
    self~process(job)
  end
  return

::method process private unguarded
  expose server workerId
  use strict arg job
  client=job[1]
  context=job[2]
  connectionConfig=job[3]
  signal on syntax name workerFailure
  conn=.HttpsConnection~new(server,client,context,connectionConfig)
  /* Deliberately synchronous inside this fixed worker activity.  No
   * untrusted accepted socket can fan out another ooRexx activity. */
  conn~run
  return
workerFailure:
  info=condition('O')
  server~logError('connection worker 'workerId' setup exception: 'info)
  if client<>.nil then client~close
  if context<>.nil then context~release
  server~releaseConnection
  return


::class HttpsConnection public
::method init
  expose server socket tlsContext config inputBuffer session peerAddress
  use strict arg server, socket, tlsContext, config
  inputBuffer=''
  session=.nil
  peerAddress=''
  peer=socket~getPeerName
  if peer<>.nil then peerAddress=peer~address':'peer~port

::method run unguarded
  expose server socket tlsContext config inputBuffer session peerAddress
  signal on syntax name trapped
  /* Nonblocking accepted sockets are essential to the bounded native
   * TLS boundary: network waits happen in RxSock select(), never while a foreign
   * OpenSSL call owns that gate. */
  if socket~ioctl('FIONBIO',1)==.nil then do
    server~logError('unable to make accepted socket nonblocking from 'peerAddress' errno='socket~errno)
    signal finished
  end
  session=tlsContext~newSession(socket,config)
  if \session~handshake then do
    if session~lastError~pos('TLS peer closed during handshake')=1 then
      server~logHandshakeAbort(peerAddress,session~lastError)
    else
      server~logError('TLS handshake failed from 'peerAddress': 'session~lastError)
    signal finished
  end

  do requestNumber=1 to config~maxRequestsPerConnection
    result=self~readRequest
    kind=result[1]
    if kind='closed' then leave
    if kind='error' then do
      ignored=self~sendResponse(result[2],.false,'GET')
      leave
    end
    request=result[2]
    response=server~dispatchSafe(request)
    if \response~isA(.HttpResponse) then response=.HttpUtil~response(500)
    keep=request~keepAlive
    if requestNumber>=config~maxRequestsPerConnection then keep=.false
    do responseHeader over response~headers
      if responseHeader~lower='connection' then if .HttpUtil~lowerContainsToken(response~headers[responseHeader],'close') then keep=.false
    end
    if \self~sendResponse(response,keep,request~method) then leave
    server~logAccess(peerAddress,request,response,session)
    if \keep then leave
  end
  signal finished

trapped:
  info=condition('O')
  server~logError('connection exception from 'peerAddress': 'info)

finished:
  if session<>.nil then session~close
  if socket<>.nil then socket~close
  tlsContext~release
  server~releaseConnection
  return

::method readRequest private
  expose config inputBuffer session peerAddress
  numeric digits 20
  crlf='0D0A'x
  marker='0D0A0D0A'x
  do while inputBuffer~pos(marker)=0
    if inputBuffer~length>=config~maxHeaderBytes then return .array~of('error',.HttpUtil~response(431))
    chunk=session~read(config~maxHeaderBytes-inputBuffer~length)
    if chunk==.nil then return .array~of('error',.HttpUtil~response(408))
    if chunk='' then return .array~of('closed',.nil)
    inputBuffer=inputBuffer||chunk
  end
  split=inputBuffer~pos(marker)
  head=inputBuffer~substr(1,split-1)
  inputBuffer=inputBuffer~substr(split+4)
  if head~length>config~maxHeaderBytes then return .array~of('error',.HttpUtil~response(431))
  if head~pos('00'x)>0 then return .array~of('error',.HttpUtil~response(400))

  p=head~pos(crlf)
  if p=0 then do
    requestLine=head
    rest=''
  end
  else do
    requestLine=head~substr(1,p-1)
    rest=head~substr(p+2)
  end
  if requestLine~length>8192 then return .array~of('error',.HttpUtil~response(414))
  if requestLine~pos('09'x)>0 then return .array~of('error',.HttpUtil~response(400))
  if requestLine~words<>3 then return .array~of('error',.HttpUtil~response(400))
  method=requestLine~word(1)
  target=requestLine~word(2)
  version=requestLine~word(3)
  if \.HttpUtil~tokenValid(method) then return .array~of('error',.HttpUtil~response(400))
  method=method~upper
  if target~substr(1,1)<>'/' then return .array~of('error',.HttpUtil~response(400))
  if target~length>8192 then return .array~of('error',.HttpUtil~response(414))
  if version<>'HTTP/1.1' & version<>'HTTP/1.0' then return .array~of('error',.HttpUtil~response(505))

  headers=.directory~new
  headerCount=0
  do while rest<>''
    p=rest~pos(crlf)
    if p=0 then do
      line=rest
      rest=''
    end
    else do
      line=rest~substr(1,p-1)
      rest=rest~substr(p+2)
    end
    if line='' then iterate
    headerCount=headerCount+1
    if headerCount>config~maxHeaderCount then return .array~of('error',.HttpUtil~response(431))
    if line~substr(1,1)=' ' | line~substr(1,1)='09'x then return .array~of('error',.HttpUtil~response(400))
    colon=line~pos(':')
    if colon<=1 then return .array~of('error',.HttpUtil~response(400))
    name=line~substr(1,colon-1)
    if \.HttpUtil~tokenValid(name) then return .array~of('error',.HttpUtil~response(400))
    value=line~substr(colon+1)~strip('B',' '||'09'x)
    if value~pos('00'x)>0 then return .array~of('error',.HttpUtil~response(400))
    key=name~lower
    if headers~hasIndex(key) then do
      if key='content-length' | key='host' then return .array~of('error',.HttpUtil~response(400))
      headers[key]=headers[key]','value
    end
    else headers[key]=value
  end

  if version='HTTP/1.1' then do
    if \headers~hasIndex('host') then return .array~of('error',.HttpUtil~response(400,'Host header required'))
    if headers['host']='' then return .array~of('error',.HttpUtil~response(400,'Host header required'))
  end
  if headers~hasIndex('transfer-encoding') then return .array~of('error',.HttpUtil~response(501,'Transfer-Encoding is not supported'))
  if headers~hasIndex('expect') then if headers['expect']~lower<>'100-continue' then return .array~of('error',.HttpUtil~response(417))

  contentLength=0
  if headers~hasIndex('content-length') then do
    cl=headers['content-length']
    if cl='' | cl~verify('0123456789')<>0 then return .array~of('error',.HttpUtil~response(400))
    if cl~length>10 then return .array~of('error',.HttpUtil~response(413))
    contentLength=cl+0
    if contentLength>config~maxBodyBytes then return .array~of('error',.HttpUtil~response(413))
  end

  if headers~hasIndex('expect') then do
    if \session~writeAll('HTTP/1.1 100 Continue'||marker) then return .array~of('closed',.nil)
  end

  do while inputBuffer~length<contentLength
    chunk=session~read(contentLength-inputBuffer~length)
    if chunk==.nil then return .array~of('error',.HttpUtil~response(408))
    if chunk='' then return .array~of('error',.HttpUtil~response(400,'Unexpected end of request body'))
    inputBuffer=inputBuffer||chunk
  end
  body=''
  if contentLength>0 then do
    body=inputBuffer~substr(1,contentLength)
    inputBuffer=inputBuffer~substr(contentLength+1)
  end

  q=target~pos('?')
  if q=0 then do; path=target; query=''; end
  else do; path=target~substr(1,q-1); query=target~substr(q+1); end

  keep=.false
  if version='HTTP/1.1' then keep=.true
  if headers~hasIndex('connection') then do
    if .HttpUtil~lowerContainsToken(headers['connection'],'close') then keep=.false
    else if version='HTTP/1.0' & .HttpUtil~lowerContainsToken(headers['connection'],'keep-alive') then keep=.true
  end

  request=.HttpRequest~new(method,target,path,query,version,headers,body,keep,peerAddress,session~protocol,session~cipher,session~contextGeneration)
  return .array~of('request',request)

::method sendResponse private
  expose session
  use strict arg response, keepAlive=.false, requestMethod='GET'
  status=response~status
  body=response~body
  if status=204 | status=304 then body=''
  wire='HTTP/1.1 'status' '.HttpUtil~reason(status)||'0D0A'x

  sawContentType=.false
  do name over response~headers
    value=response~headers[name]
    if name~lower='connection' | name~lower='content-length' then iterate
    if \.HttpUtil~tokenValid(name) then iterate
    if value~pos('0D'x)>0 | value~pos('0A'x)>0 | value~pos('00'x)>0 then iterate
    if name~lower='content-type' then sawContentType=.true
    wire=wire||name': 'value||'0D0A'x
  end
  if \sawContentType & body<>'' then wire=wire||'Content-Type: application/octet-stream'||'0D0A'x
  wire=wire||'Content-Length: 'body~length||'0D0A'x
  wire=wire||'X-Content-Type-Options: nosniff'||'0D0A'x
  if keepAlive then wire=wire||'Connection: keep-alive'||'0D0A'x
  else wire=wire||'Connection: close'||'0D0A'x
  wire=wire||'0D0A'x
  if requestMethod<>'HEAD' & body<>'' then wire=wire||body
  return session~writeAll(wire)


::class HttpsServer public
::attribute actualPort get
::attribute tlsProviderPath get
::attribute tlsVersion get
::attribute foreignRuntimeVersion get
::attribute foreignDispatcher get
::attribute foreignThreadingMode get
::attribute tlsPolicy get
::attribute nativeConcurrencyPolicy get
::attribute tlsIoModel get
::attribute tlsGeneration get
::attribute lifecycleState get

::method init
  expose config tlsContext routes interceptors requestSequence listener activeConnections stopping actualPort tlsProviderPath tlsVersion foreignRuntimeVersion foreignDispatcher foreignThreadingMode tlsPolicy nativeConcurrencyPolicy tlsIoModel tlsGeneration lifecycleState nativeGate connectionQueue connectionWorkers workerActivities
  use strict arg config
  config~validate
  routes=.directory~new
  interceptors=.array~new
  requestSequence=0
  listener=.nil
  activeConnections=0
  stopping=.false
  actualPort=0
  tlsGeneration=1
  lifecycleState='created'
  tlsIoModel='memory-bio-rxsock'
  nativeGate=.TlsNativeGate~new(config~nativeTlsConcurrency)
  connectionQueue=.HttpsConnectionQueue~new(config~maxPendingConnections)
  connectionWorkers=.array~new
  workerActivities=.array~new
  tlsContext=.TlsContext~new(config,tlsGeneration,nativeGate)
  self~adoptTlsObservability(tlsContext)

::method adoptTlsObservability private
  expose tlsProviderPath tlsVersion foreignRuntimeVersion foreignDispatcher foreignThreadingMode tlsPolicy nativeConcurrencyPolicy
  use strict arg context
  tlsProviderPath=context~providerPath
  tlsVersion=context~opensslVersion
  foreignRuntimeVersion=context~foreignRuntimeVersion
  foreignDispatcher=context~foreignDispatcher
  foreignThreadingMode=context~foreignThreadingMode
  tlsPolicy=context~tlsPolicy
  nativeConcurrencyPolicy=context~nativeConcurrencyPolicy

::method route
  expose routes listener
  use strict arg method, path, target, handlerMethod
  if listener<>.nil then raise syntax 40.900 array('Routes are immutable after server start')
  if \.HttpUtil~tokenValid(method) then raise syntax 40.900 array('Invalid route method',method)
  if path='' | path~substr(1,1)<>'/' then raise syntax 40.900 array('Invalid route path',path)
  key=method~upper||' '||path
  routes[key]=.array~of(target,handlerMethod)
  return self

::method interceptor
  expose interceptors listener
  use strict arg target, beforeMethod='beforeRequest', afterMethod='afterResponse'
  if listener<>.nil then raise syntax 40.900 array('Interceptors are immutable after server start')
  interceptors~append(.HttpInterceptorBinding~new(target,beforeMethod,afterMethod))
  return self

::method interceptorCount
  expose interceptors
  return interceptors~items

::method newRequestContext private
  expose requestSequence
  use strict arg request
  requestSequence=requestSequence+1
  context=.HttpExchangeContext~new(requestSequence,request)
  request~attachContext(context)
  return context

::method dispatchRoute private unguarded
  expose routes
  use strict arg request
  key=request~method||' '||request~path
  if routes~hasIndex(key) then do
    route=routes[key]
    args=.array~of(request)
    return route[1]~sendWith(route[2],args)
  end

  allow=''
  suffix=' '||request~path
  do routeKey over routes
    if routeKey~right(suffix~length)=suffix then do
      verb=routeKey~word(1)
      if allow<>'' then allow=allow', '
      allow=allow||verb
    end
  end
  if allow<>'' then return .HttpUtil~response(405)~header('Allow',allow)
  return .HttpUtil~response(404)

::method dispatchRouteSafe private unguarded
  use strict arg request
  signal on syntax name routeFailure
  response=self~dispatchRoute(request)
  if response~isA(.HttpResponse) then return response
  self~logError('route returned a non-HttpResponse for 'request~method' 'request~path)
  return .HttpUtil~response(500)
routeFailure:
  info=condition('O')
  self~logError('route exception for 'request~method' 'request~path': 'info)
  return .HttpUtil~response(500)

::method callInterceptorBefore private unguarded
  use strict arg binding, request, context
  signal on syntax name beforeFailure
  decision=binding~before(request,context)
  return .array~of('ok',decision)
beforeFailure:
  info=condition('O')
  self~logError('interceptor before exception for 'request~method' 'request~path': 'info)
  return .array~of('error',.HttpUtil~response(500))

::method callInterceptorAfter private unguarded
  use strict arg binding, request, response, context
  signal on syntax name afterFailure
  updated=binding~after(request,response,context)
  return .array~of('ok',updated)
afterFailure:
  info=condition('O')
  self~logError('interceptor after exception for 'request~method' 'request~path': 'info)
  return .array~of('error',.HttpUtil~response(500))

::method dispatch unguarded
  expose interceptors
  use strict arg request
  context=self~newRequestContext(request)
  executed=.array~new
  response=.nil

  /* Before hooks run in registration order. Returning nil continues;
   * returning HttpResponse short-circuits routing. A failed before hook is
   * converted to 500, while already-completed outer hooks still unwind. */
  do binding over interceptors
    step=self~callInterceptorBefore(binding,request,context)
    if step[1]='error' then do
      response=step[2]
      leave
    end
    executed~append(binding)
    decision=step[2]
    if decision==.nil then iterate
    if \decision~isA(.HttpResponse) then do
      self~logError('interceptor before method returned a non-HttpResponse for 'request~method' 'request~path)
      response=.HttpUtil~response(500)
      leave
    end
    response=decision
    leave
  end

  if response==.nil then response=self~dispatchRouteSafe(request)

  /* After hooks unwind in reverse order. nil preserves the current response;
   * HttpResponse replaces it. A failed after hook turns the response into 500
   * but does not prevent already-entered outer hooks from running, so audit or
   * security-effect wrappers can still observe failure containment. */
  do index=executed~items to 1 by -1
    step=self~callInterceptorAfter(executed[index],request,response,context)
    if step[1]='error' then do
      response=step[2]
      iterate
    end
    updated=step[2]
    if updated==.nil then iterate
    if \updated~isA(.HttpResponse) then do
      self~logError('interceptor after method returned a non-HttpResponse for 'request~method' 'request~path)
      response=.HttpUtil~response(500)
      iterate
    end
    response=updated
  end
  return response

::method dispatchSafe unguarded
  use strict arg request
  signal on syntax name dispatchFailure
  response=self~dispatch(request)
  if response~isA(.HttpResponse) then return response
  self~logError('request pipeline returned a non-HttpResponse for 'request~method' 'request~path)
  return .HttpUtil~response(500)
dispatchFailure:
  info=condition('O')
  self~logError('request pipeline exception for 'request~method' 'request~path': 'info)
  return .HttpUtil~response(500)

::method acquireConnectionLease
  expose activeConnections config stopping tlsContext
  if stopping | tlsContext==.nil then return .nil
  if activeConnections>=config~maxConnections then return .nil
  /* Pin the exact TLS generation and its immutable config snapshot while the
   * server guard is held. Reload cannot interleave between these two values. */
  if \tlsContext~pin then return .nil
  activeConnections=activeConnections+1
  return .array~of(tlsContext,config)

::method releaseConnection
  expose activeConnections lifecycleState stopping
  if activeConnections>0 then activeConnections=activeConnections-1
  if stopping & activeConnections=0 then lifecycleState='stopped'

::method activeConnectionCount
  expose activeConnections
  return activeConnections

::method nativeTlsConcurrency
  expose nativeGate
  return nativeGate~laneCount

::method nativeTlsMaxConcurrent
  expose nativeGate
  return nativeGate~maxConcurrent

::method nativeTlsInvocationCount
  expose nativeGate
  return nativeGate~invocationCount

::method connectionWorkerCount
  expose config
  return config~connectionWorkers

::method pendingConnectionCount
  expose connectionQueue
  return connectionQueue~pendingCount

::method connectionQueueCapacity
  expose connectionQueue
  return connectionQueue~capacity

::method connectionQueueHighWaterMark
  expose connectionQueue
  return connectionQueue~highWaterMark

::method connectionQueueAccepted
  expose connectionQueue
  return connectionQueue~accepted

::method connectionQueueRejected
  expose connectionQueue
  return connectionQueue~rejected

::method nextAcceptedConnection unguarded
  expose connectionQueue
  return connectionQueue~next

::method startConnectionWorkers private unguarded
  expose config connectionWorkers workerActivities
  do workerId=1 to config~connectionWorkers
    worker=.HttpsConnectionWorker~new(self,workerId)
    connectionWorkers~append(worker)
    workerActivities~append(worker~start('run'))
  end

::method enqueueAcceptedConnection private
  expose connectionQueue
  use strict arg client, context, connectionConfig
  return connectionQueue~add(.array~of(client,context,connectionConfig))

::method rejectAcceptedConnection private
  use strict arg client, context
  if client<>.nil then client~close
  if context<>.nil then context~release
  self~releaseConnection

::method reloadTls
  expose config tlsContext tlsGeneration stopping nativeGate
  use strict arg certificateFile='', privateKeyFile='', clientCAFile=.nil, requireClientCertificate=.nil
  if stopping then raise syntax 40.900 array('TLS reload refused while server is draining')
  nextConfig=config~copy
  if certificateFile<>'' then nextConfig~certificateFile=certificateFile
  if privateKeyFile<>'' then nextConfig~privateKeyFile=privateKeyFile
  if clientCAFile<>.nil then nextConfig~clientCAFile=clientCAFile
  if requireClientCertificate<>.nil then nextConfig~requireClientCertificate=requireClientCertificate
  nextConfig~validate

  nextGeneration=tlsGeneration+1
  /* Build and validate the replacement completely before publishing it.
   * If construction raises, the current generation remains authoritative. */
  candidate=.TlsContext~new(nextConfig,nextGeneration,nativeGate)
  previous=tlsContext
  tlsContext=candidate
  config=nextConfig
  tlsGeneration=nextGeneration
  self~adoptTlsObservability(candidate)
  pins=previous~retire
  say 'OOREXX_HTTPS_TLS_RELOADED generation='tlsGeneration' previousPins='pins' tls='candidate~opensslVersion' provider='candidate~providerPath
  return tlsGeneration

::method serve unguarded
  expose config listener stopping actualPort lifecycleState
  signal on halt name serveHalted
  listener=.Socket~new('AF_INET','SOCK_STREAM',0)
  ignored=listener~setOption('SO_REUSEADDR',1)
  address=.InetAddress~new(config~bindAddress,config~port)
  if listener~bind(address)<>0 then raise syntax 40.900 array('Unable to bind HTTPS listener',config~bindAddress,config~port,listener~errno)
  if listener~listen(config~backlog)<>0 then raise syntax 40.900 array('Unable to listen',listener~errno)
  if listener~ioctl('FIONBIO',1)==.nil then raise syntax 40.900 array('Unable to make HTTPS listener nonblocking',listener~errno)
  bound=listener~getSockName
  if bound<>.nil then actualPort=bound~port
  else actualPort=config~port
  lifecycleState='accepting'
  self~startConnectionWorkers
  say 'OOREXX_HTTPS_READY address='config~bindAddress' port='actualPort' tls='self~tlsVersion' provider='self~tlsProviderPath' foreign='self~foreignRuntimeVersion' dispatcher='self~foreignDispatcher' threading='self~foreignThreadingMode' native='self~nativeConcurrencyPolicy' nativeLanes='self~nativeTlsConcurrency' io='self~tlsIoModel' workers='self~connectionWorkerCount' queue='self~connectionQueueCapacity' policy='self~tlsPolicy' generation='self~tlsGeneration

  do while \stopping
    reads=.array~of(listener)
    writes=.array~new
    excepts=.array~of(listener)
    ready=listener~select(reads,writes,excepts,1)
    if ready==.nil then do
      if stopping then leave
      iterate
    end
    if ready=0 then iterate
    client=listener~accept
    if client==.nil then do
      if stopping then leave
      iterate
    end
    lease=self~acquireConnectionLease
    if lease==.nil then do
      client~close
      iterate
    end
    context=lease[1]
    connectionConfig=lease[2]
    if \self~enqueueAcceptedConnection(client,context,connectionConfig) then do
      self~rejectAcceptedConnection(client,context)
      iterate
    end
  end
  if stopping & self~activeConnectionCount=0 then lifecycleState='stopped'
  return

serveHalted:
  self~stop
  return

::method stop
  expose stopping listener lifecycleState connectionQueue
  if stopping then return
  stopping=.true
  lifecycleState='draining'
  if listener<>.nil then listener~close
  if connectionQueue<>.nil then connectionQueue~stop

::method drain unguarded
  use strict arg timeoutSeconds=30
  if timeoutSeconds~datatype('N')=0 | timeoutSeconds<0 then raise syntax 40.900 array('Invalid drain timeout',timeoutSeconds)
  ignored=time('R')
  do forever
    if self~activeConnectionCount=0 then do
      self~markStopped
      return .true
    end
    if time('E')>=timeoutSeconds then return .false
    call SysSleep .05
  end

::method stopAndDrain unguarded
  use strict arg timeoutSeconds=30
  self~stop
  return self~drain(timeoutSeconds)

::method markStopped private
  expose lifecycleState
  lifecycleState='stopped'

::method logAccess unguarded
  expose config
  use strict arg peer, request, response, session
  if \config~accessLog then return
  requestId='-'
  if request~context<>.nil then requestId=request~context~requestId
  say 'ACCESS request='requestId' peer='peer' method='request~method' target='request~target' status='response~status' tls='session~protocol' cipher='session~cipher' generation='session~contextGeneration

::method logHandshakeAbort unguarded
  expose config
  use strict arg peer, detail
  /* A remote peer that vanishes before TLS establishment is ordinary network
   * churn / hostile admission noise, not a server fault.  Keep it out of the
   * ERROR channel so abort floods cannot amplify into log contention. */
  if config~accessLog then say 'ABORT peer='peer' detail='detail

::method logError unguarded
  use strict arg text
  say 'ERROR 'text

::method close
  expose tlsContext listener stopping lifecycleState connectionQueue
  stopping=.true
  if connectionQueue<>.nil then connectionQueue~stop
  if lifecycleState<>'stopped' then lifecycleState='draining'
  if listener<>.nil then do
    listener~close
    listener=.nil
  end
  if tlsContext<>.nil then do
    tlsContext~retire
    tlsContext=.nil
  end
  if self~activeConnectionCount=0 then lifecycleState='stopped'

::method uninit
  self~close

::requires 'socket.cls'
::requires 'foreign.cls'
