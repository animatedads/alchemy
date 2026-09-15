/* ooRexx API Client v0.4 - native HTTP/1.1 + HTTP/2 HTTPS transport.
 *
 * Deliberately provider-neutral and deliberately not a curl subprocess wrapper.
 * TCP I/O is owned by RxSock. TLS is OpenSSL through Foreign Runtime memory BIOs.
 * HTTP/1.1 remains bounded with Connection: close; HTTP/2 is ALPN-negotiated and
 * framed/HPACK-managed by libnghttp2 through Foreign Runtime.
 */

::class ApiHttpTransportBuild public
::constant VERSION "0.4"
::constant API "api.http.transport/0.4"

::class ApiUrl public
::attribute scheme get
::attribute host get
::attribute port get
::attribute target get
::method init
  expose scheme host port target
  use strict arg url
  text=url~string~strip
  marker=text~pos("://")
  if marker=0 then raise syntax 88.900 array("absolute http/https URL required",text)
  scheme=text~left(marker-1)~lower
  if scheme<>"http" & scheme<>"https" then raise syntax 88.900 array("unsupported URL scheme",scheme)
  rest=text~substr(marker+3)
  slash=rest~pos("/")
  if slash=0 then do; authority=rest; target="/"; end
  else do; authority=rest~left(slash-1); target=rest~substr(slash); end
  if authority="" then raise syntax 88.900 array("URL host required",text)
  if authority~pos("@")>0 then raise syntax 88.900 array("userinfo in URL is not supported")
  /* v0.3 intentionally accepts DNS/IPv4 host syntax, not IPv6 literals. */
  if authority~left(1)="[" then raise syntax 88.900 array("IPv6 URL literals are not yet supported")
  colon=authority~lastPos(":")
  if colon>0 then do
    host=authority~left(colon-1)
    p=authority~substr(colon+1)
    if p="" | \datatype(p,"W") then raise syntax 88.900 array("invalid URL port",p)
    port=p+0
  end
  else do
    host=authority
    if scheme="https" then port=443; else port=80
  end
  if host="" then raise syntax 88.900 array("URL host required",text)
  if port<1 | port>65535 then raise syntax 88.900 array("URL port out of range",port)
  if target="" then target="/"
::method authority
  expose scheme host port
  if (scheme="https" & port=443) | (scheme="http" & port=80) then return host
  return host || ":" || port
::method origin
  expose scheme
  return scheme || "://" || self~authority
::method absolute
  expose scheme target
  return self~origin || target
::method sameOrigin
  use strict arg other
  return self~origin~lower = other~origin~lower
::method resolve
  expose scheme target
  use strict arg location
  loc=location~string~strip
  if loc="" then raise syntax 88.900 array("redirect Location must not be empty")
  if loc~pos("://")>0 then return .ApiUrl~new(loc)
  if loc~left(2)="//" then return .ApiUrl~new(scheme || ":" || loc)
  base=self~origin
  if loc~left(1)="/" then return .ApiUrl~new(base || self~normalizeTarget(loc))
  q=target~pos("?"); if q>0 then path=target~left(q-1); else path=target
  if loc~left(1)="?" then return .ApiUrl~new(base || path || loc)
  slash=path~lastPos("/")
  if slash=0 then parent="/"; else parent=path~left(slash)
  return .ApiUrl~new(base || self~normalizeTarget(parent || loc))
::method normalizeTarget private
  use strict arg raw
  q=raw~pos("?")
  if q>0 then do; path=raw~left(q-1); suffix=raw~substr(q); end
  else do; path=raw; suffix=""; end
  parts=path~makeArray("/")
  stack=.array~new
  do i=1 to parts~items
    part=parts[i]
    if part="" | part="." then iterate
    if part=".." then do; if stack~items>0 then stack~delete(stack~items); iterate; end
    stack~append(part)
  end
  out="/"
  do i=1 to stack~items
    if i>1 then out=out || "/"
    out=out || stack[i]
  end
  if path~right(1)="/" & out~right(1)<>"/" then out=out || "/"
  return out || suffix

::class ApiHttpTransportConfig public
::attribute bridgeDirectory
::attribute caFile
::attribute verifyPeer
::attribute readTimeout
::attribute writeTimeout
::attribute readChunkSize
::attribute maxHeaderBytes
::attribute maxBodyBytes
::attribute userAgent
::attribute minimumTlsVersion
::attribute followRedirects
::attribute maxRedirects
::attribute allowCrossOriginRedirects
::attribute allowHttpsDowngrade
::attribute legacyPostRedirectToGet
::attribute httpVersionPolicy
::attribute h2BridgeFile
::method init
  expose bridgeDirectory caFile verifyPeer readTimeout writeTimeout readChunkSize maxHeaderBytes maxBodyBytes userAgent minimumTlsVersion followRedirects maxRedirects allowCrossOriginRedirects allowHttpsDowngrade legacyPostRedirectToGet httpVersionPolicy h2BridgeFile
  bridgeDirectory=""; caFile=""; verifyPeer=.true
  readTimeout=30; writeTimeout=30; readChunkSize=16384
  maxHeaderBytes=65536; maxBodyBytes=67108864
  userAgent="ooRexx-ApiClient/0.4"
  minimumTlsVersion="TLS1.2"
  followRedirects=.false; maxRedirects=5
  allowCrossOriginRedirects=.false; allowHttpsDowngrade=.false; legacyPostRedirectToGet=.false
  httpVersionPolicy="NEGOTIATE"; h2BridgeFile=""
::method validate
  expose bridgeDirectory verifyPeer readTimeout writeTimeout readChunkSize maxHeaderBytes maxBodyBytes minimumTlsVersion followRedirects maxRedirects allowCrossOriginRedirects allowHttpsDowngrade legacyPostRedirectToGet httpVersionPolicy
  if bridgeDirectory="" then raise syntax 88.900 array("OpenSSL bridgeDirectory is required")
  if verifyPeer<>.true & verifyPeer<>.false then raise syntax 88.900 array("verifyPeer must be logical")
  if readTimeout<=0 | writeTimeout<=0 then raise syntax 88.900 array("read/write timeout must be positive")
  if readChunkSize<1024 then raise syntax 88.900 array("readChunkSize too small")
  if maxHeaderBytes<1024 | maxBodyBytes<0 then raise syntax 88.900 array("invalid HTTP size limits")
  if minimumTlsVersion<>"TLS1.2" then raise syntax 88.900 array("only TLS1.2 minimum policy is qualified in v0.4")
  if followRedirects<>.true & followRedirects<>.false then raise syntax 88.900 array("followRedirects must be logical")
  if maxRedirects<0 | maxRedirects>20 then raise syntax 88.900 array("maxRedirects out of range",maxRedirects)
  if allowCrossOriginRedirects<>.true & allowCrossOriginRedirects<>.false then raise syntax 88.900 array("allowCrossOriginRedirects must be logical")
  if allowHttpsDowngrade<>.true & allowHttpsDowngrade<>.false then raise syntax 88.900 array("allowHttpsDowngrade must be logical")
  if legacyPostRedirectToGet<>.true & legacyPostRedirectToGet<>.false then raise syntax 88.900 array("legacyPostRedirectToGet must be logical")
  httpVersionPolicy=httpVersionPolicy~string~upper
  if httpVersionPolicy<>"HTTP1_ONLY" & httpVersionPolicy<>"NEGOTIATE" & httpVersionPolicy<>"HTTP2_REQUIRED" then raise syntax 88.900 array("invalid httpVersionPolicy",httpVersionPolicy)
  return self

::class ApiHttpCodec public
::method lowerHeaderName class
  use strict arg name
  return name~strip~lower
::method headerValue class
  use strict arg headers, name, default=""
  v=headers~at(name~lower)
  if v==.nil then v=headers~at(name)
  if v==.nil then v=headers~at(name~upper)
  if v==.nil then return default
  return v~string
::method hasToken class
  use strict arg value, wanted
  rest=value
  do while rest<>""
    p=rest~pos(",")
    if p=0 then do; item=rest; rest=""; end
    else do; item=rest~left(p-1); rest=rest~substr(p+1); end
    if item~strip~lower=wanted~lower then return .true
  end
  return .false
::method buildRequest class
  use strict arg request, url, config
  crlf="0d0a"x
  headers=.directory~new
  do k over request~headers
    headers[k~string~lower]=request~headers[k]~string
  end
  if headers~at("host")==.nil then headers["host"]=url~authority
  if headers~at("user-agent")==.nil then headers["user-agent"]=config~userAgent
  if headers~at("accept")==.nil then headers["accept"]="*/*"
  if headers~at("connection")==.nil then headers["connection"]="close"
  body=request~body~string
  if body<>"" & headers~at("content-length")==.nil then headers["content-length"]=body~length~string
  if body="" & (request~method="POST" | request~method="PUT" | request~method="PATCH") & headers~at("content-length")==.nil then headers["content-length"]="0"
  text=request~method || " " || url~target || " HTTP/1.1" || crlf
  keys=.array~new
  do k over headers; keys~append(k); end
  keys~sort
  do k over keys
    text=text || k || ": " || headers[k] || crlf
  end
  return text || crlf || body

::class ApiHttpHead public
::attribute status get
::attribute reason get
::attribute headers get
::attribute bodyPrefix get
::method init
  expose status reason headers bodyPrefix
  use strict arg statusArg,reasonArg,headersArg,prefixArg=""
  status=statusArg+0; reason=reasonArg~string; headers=headersArg; bodyPrefix=prefixArg

::class ApiHttpParser public
::method parseHead class
  use strict arg raw
  sep="0d0a0d0a"x; p=raw~pos(sep)
  if p=0 then return .nil
  head=raw~left(p-1); prefix=raw~substr(p+4)
  lines=head~makeArray("0d0a"x)
  if lines==.nil | lines~items<1 then raise syntax 88.900 array("empty HTTP response head")
  first=lines[1]
  parse var first version status reason
  if version~left(5)<>"HTTP/" | \datatype(status,"W") then raise syntax 88.900 array("invalid HTTP status line",first)
  headers=.directory~new
  do i=2 to lines~items
    line=lines[i]
    colon=line~pos(":")
    if colon<=1 then raise syntax 88.900 array("invalid HTTP header",line)
    name=line~left(colon-1)~strip~lower; value=line~substr(colon+1)~strip
    old=headers~at(name)
    if old==.nil then headers[name]=value
    else headers[name]=old || ", " || value
  end
  return .ApiHttpHead~new(status,reason,headers,prefix)
::method decodeChunked class
  use strict arg raw, maxBytes=67108864
  posn=1; out=""
  crlf="0d0a"x
  do forever
    eol=raw~pos(crlf,posn)
    if eol=0 then raise syntax 88.900 array("truncated chunk-size line")
    line=raw~substr(posn,eol-posn)~strip
    semi=line~pos(";"); if semi>0 then line=line~left(semi-1)~strip
    if line="" then raise syntax 88.900 array("empty chunk size")
    size=self~hexNumber(line)
    posn=eol+2
    if size=0 then return out
    if posn+size-1>raw~length then raise syntax 88.900 array("truncated HTTP chunk",size)
    out=out || raw~substr(posn,size)
    if out~length>maxBytes then raise syntax 88.900 array("HTTP body exceeds configured maximum",maxBytes)
    posn=posn+size
    if raw~substr(posn,2)<>crlf then raise syntax 88.900 array("invalid HTTP chunk terminator")
    posn=posn+2
  end
::method hexNumber class private
  use strict arg text
  digits="0123456789abcdef"; n=0
  t=text~lower
  do i=1 to t~length
    d=digits~pos(t~substr(i,1))
    if d=0 then raise syntax 88.900 array("invalid hexadecimal number",text)
    n=n*16+(d-1)
  end
  return n

::class ApiSseEvent public
::attribute event get
::attribute data get
::attribute id get
::attribute retry get
::method init
  expose event data id retry
  use strict arg eventArg="message",dataArg="",idArg="",retryArg=0
  event=eventArg~string; data=dataArg~string; id=idArg~string; retry=retryArg+0

::class ApiSseParser public
::method parse class
  use strict arg body
  text=changestr("0d0a"x,body,"0a"x)
  text=changestr("0d"x,text,"0a"x)
  events=.array~new
  eventName="message"; dataLines=.array~new; id=""; retry=0
  lines=text~makeArray("0a"x)
  do i=1 to lines~items
    line=lines[i]
    if line="" then do
      if dataLines~items>0 | eventName<>"message" | id<>"" | retry<>0 then events~append(self~makeEvent(eventName,dataLines,id,retry))
      eventName="message"; dataLines=.array~new; id=""; retry=0
      iterate
    end
    if line~left(1)=":" then iterate
    colon=line~pos(":")
    if colon=0 then do; field=line; value=""; end
    else do
      field=line~left(colon-1); value=line~substr(colon+1)
      if value~left(1)=" " then value=value~substr(2)
    end
    select
      when field="event" then eventName=value
      when field="data" then dataLines~append(value)
      when field="id" then id=value
      when field="retry" then if datatype(value,"W") then retry=value+0
      otherwise nop
    end
  end
  if dataLines~items>0 | eventName<>"message" | id<>"" | retry<>0 then events~append(self~makeEvent(eventName,dataLines,id,retry))
  return events
::method makeEvent class private
  use strict arg name,lines,id,retry
  data=""
  do i=1 to lines~items
    if i>1 then data=data || "0a"x
    data=data || lines[i]
  end
  return .ApiSseEvent~new(name,data,id,retry)

/* ---------- serialized Foreign Runtime lane ---------- */
::class ApiTlsNativeLane
::method init
  expose owner
  use strict arg owner
::method invoke
  expose owner
  use strict arg library,name,args
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
  use strict arg library,name,args,ssl
  owner~entered
  signal on syntax name sslStepFailure
  rc=library~invokeArray(name,args); ec=0
  if rc<=0 then ec=library~invokeArray("ssl_get_error",.array~of(ssl,rc))
  owner~left
  return .array~of(rc,ec)
sslStepFailure:
  owner~left
  raise propagate
::method closeObject
  expose owner
  use strict arg object
  owner~entered
  signal on syntax name closeFailure
  if object<>.nil then if \object~closed then object~close
  owner~left
  return .nil
closeFailure:
  owner~left
  raise propagate
::method closeLibrary
  expose owner
  use strict arg library
  owner~entered
  signal on syntax name closeLibFailure
  if library<>.nil then library~close
  owner~left
  return .nil
closeLibFailure:
  owner~left
  raise propagate

::class ApiTlsNativeGate public
::method init
  expose lane active maxConcurrent invocationCount
  lane=.ApiTlsNativeLane~new(self); active=0; maxConcurrent=0; invocationCount=0
::method nextLane
  expose lane invocationCount
  invocationCount+=1; return lane
::method entered
  expose active maxConcurrent
  active+=1; if active>maxConcurrent then maxConcurrent=active
::method left
  expose active
  if active>0 then active-=1
::method invoke unguarded
  use strict arg library,name,args
  return self~nextLane~invoke(library,name,args)
::method sslStep unguarded
  use strict arg library,name,args,ssl
  return self~nextLane~sslStep(library,name,args,ssl)
::method closeObject unguarded
  use strict arg object
  return self~nextLane~closeObject(object)
::method closeLibrary unguarded
  use strict arg library
  return self~nextLane~closeLibrary(library)

::class ApiTlsForeignLibrary public
::method init
  expose library gate
  use strict arg library,gate
::method unknown unguarded
  expose library gate
  use strict arg name,args
  return gate~invoke(library,name,args)
::method sslStep unguarded
  expose library gate
  use strict arg name,args,ssl
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
  if library<>.nil then do; gate~closeLibrary(library); library=.nil; end

::class ApiTlsClientContext public
::attribute opensslVersion get
::attribute providerPath get
::method init
  expose config tls bio err h2 method ctx opensslVersion providerPath gate closed
  use strict arg config
  config~validate
  gate=.ApiTlsNativeGate~new
  bridge=config~bridgeDirectory
  tls=.ApiTlsForeignLibrary~new(.foreign~load(bridge || "/openssl_tls_client.bridge.json"),gate)
  bio=.ApiTlsForeignLibrary~new(.foreign~load(bridge || "/openssl_bio.bridge.json"),gate)
  err=.ApiTlsForeignLibrary~new(.foreign~load(bridge || "/openssl_crypto_error.bridge.json"),gate)
  h2=.nil
  if config~httpVersionPolicy<>"HTTP1_ONLY" then do
    h2File=config~h2BridgeFile
    if h2File="" then h2File=bridge || "/api_h2.bridge.json"
    signal on syntax name h2Unavailable
    h2=.ApiTlsForeignLibrary~new(.foreign~load(h2File),gate)
    signal off syntax
  end
  providerPath=tls~providerPath; opensslVersion=err~openssl_version(0)
  if tls~threadingMode<>"thread-safe" | bio~threadingMode<>"thread-safe" | err~threadingMode<>"thread-safe" then raise syntax 88.900 array("OpenSSL Foreign Runtime bridges must be thread-safe")
  method=tls~tls_client_method
  if method==.nil then raise syntax 88.900 array("TLS_client_method returned null")
  ctx=tls~ctx_new(method)
  if ctx==.nil then raise syntax 88.900 array("SSL_CTX_new returned null",self~errorText)
  /* SSL_CTRL_SET_MIN_PROTO_VERSION=123, TLS1_2_VERSION=0x0303. */
  if tls~ctx_ctrl(ctx,123,771,.nil)<>1 then raise syntax 88.900 array("Unable to set TLS 1.2 minimum",self~errorText)
  if config~verifyPeer then do
    if config~caFile<>"" then do
      if tls~ctx_load_verify_file(ctx,config~caFile)<>1 then raise syntax 88.900 array("Unable to load CA file",config~caFile,self~errorText)
    end
    else do
      if tls~ctx_set_default_verify_paths(ctx)<>1 then raise syntax 88.900 array("Unable to load system trust store",self~errorText)
    end
    ignored=tls~ctx_set_verify(ctx,1,.nil) /* SSL_VERIFY_PEER */
  end
  else ignored=tls~ctx_set_verify(ctx,0,.nil)
  closed=.false
  return
h2Unavailable:
  signal off syntax
  h2=.nil
  if config~httpVersionPolicy="HTTP2_REQUIRED" then raise syntax 88.900 array("HTTP/2 native bridge unavailable",condition("D"))
  closed=.false
::method tlsLibrary
  expose tls; return tls
::method bioLibrary
  expose bio; return bio
::method h2Library
  expose h2; return h2
::method sslContext
  expose ctx; return ctx
::method errorText
  expose err
  parts=.array~new
  do forever
    code=err~err_get_error
    if code=0 then leave
    reason=err~err_reason_error_string(code); if reason==.nil then reason="OpenSSL error " || code
    parts~append(reason)
  end
  if parts~items=0 then return "no OpenSSL error detail"
  text=""; do i=1 to parts~items; if i>1 then text=text || "; "; text=text || parts[i]; end
  return text
::method close
  expose tls bio err h2 method ctx closed
  if closed then return
  closed=.true
  if ctx<>.nil then do; tls~closeObject(ctx); ctx=.nil; end
  if method<>.nil then do; tls~closeObject(method); method=.nil; end
  if tls<>.nil then do; tls~close; tls=.nil; end
  if bio<>.nil then do; bio~close; bio=.nil; end
  if err<>.nil then do; err~close; err=.nil; end
  if h2<>.nil then do; h2~close; h2=.nil; end
::method uninit
  self~close

::class ApiTlsClientSession public
::attribute protocol get
::attribute cipher get
::attribute lastError get
::attribute applicationProtocol get
::method init
  expose context tls bio h2 ssl socket rbio wbio buffer wireBuffer bufferSize host protocol cipher applicationProtocol lastError closed config
  use strict arg context,socket,host,config
  tls=context~tlsLibrary; bio=context~bioLibrary; h2=context~h2Library; bufferSize=config~readChunkSize
  ssl=tls~ssl_new(context~sslContext)
  if ssl==.nil then raise syntax 88.900 array("SSL_new returned null",context~errorText)
  memMethod=bio~bio_s_mem
  if memMethod==.nil then raise syntax 88.900 array("BIO_s_mem returned null",context~errorText)
  rbio=bio~bio_new(memMethod); wbio=bio~bio_new(memMethod); bio~closeObject(memMethod)
  if rbio==.nil | wbio==.nil then raise syntax 88.900 array("BIO_new failed",context~errorText)
  tls~ssl_set0_rbio(ssl,rbio); tls~ssl_set0_wbio(ssl,wbio)
  tls~ssl_set_connect_state(ssl)
  if h2<>.nil then do
    offerH2=(config~httpVersionPolicy<>"HTTP1_ONLY")
    if h2~ssl_set_client_alpn(ssl,offerH2)<>0 then raise syntax 88.900 array("Unable to configure TLS ALPN")
  end
  if config~verifyPeer then if tls~ssl_set1_host(ssl,host)<>1 then raise syntax 88.900 array("SSL_set1_host failed",host,context~errorText)
  /* SSL_CTRL_SET_TLSEXT_HOSTNAME=55, TLSEXT_NAMETYPE_host_name=0. */
  if tls~ssl_ctrl(ssl,55,0,host)<=0 then raise syntax 88.900 array("Unable to configure TLS SNI",host,context~errorText)
  buffer=.foreign~buffer(bufferSize); wireBuffer=.foreign~buffer(bufferSize)
  protocol=""; cipher=""; applicationProtocol=""; lastError=""; closed=.false
::method waitReady private
  expose socket lastError
  use strict arg errorCode,timeoutSeconds
  reads=.array~new; writes=.array~new; excepts=.array~of(socket)
  if errorCode=2 then reads~append(socket); else if errorCode=3 then writes~append(socket); else return .false
  rc=socket~select(reads,writes,excepts,timeoutSeconds)
  if rc==.nil then do; lastError="socket select failed errno=" || socket~errno; return .false; end
  if rc=0 then do; lastError="socket readiness timeout after " || timeoutSeconds || " seconds"; return .false; end
  return .true
::method receiveEncrypted private
  expose socket bio rbio bufferSize lastError config
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
  offset=1; total=data~length
  do attempt=1 to 100 while offset<=total
    rc=socket~send(data~substr(offset))
    if rc>0 then do; offset+=rc; iterate; end
    if rc=0 then do; lastError="socket send returned zero"; return .false; end
    if \self~waitReady(3,timeoutSeconds) then return .false
  end
  return offset>total
::method drainOutput private
  expose bio wbio wireBuffer bufferSize lastError config
  do forever
    rc=bio~bio_read(wbio,wireBuffer,bufferSize)
    if rc<=0 then return .true
    wire=wireBuffer~bytes~substr(1,rc)
    if \self~sendRaw(wire,config~writeTimeout) then return .false
  end
::method handshake
  expose context tls h2 ssl protocol cipher applicationProtocol lastError config
  call time "R"
  do attempt=1 to 100
    step=tls~sslStep("ssl_do_handshake",.array~of(ssl),ssl); rc=step[1]; ec=step[2]
    if \self~drainOutput then return .false
    if rc=1 then do
      if config~verifyPeer then do
        verify=tls~ssl_get_verify_result(ssl)
        if verify<>0 then do; lastError="certificate verification failed code=" || verify; return .false; end
      end
      protocol=tls~ssl_get_version(ssl)
      if h2<>.nil then applicationProtocol=h2~ssl_selected_alpn(ssl)
      if applicationProtocol="" then applicationProtocol="http/1.1"
      c=tls~ssl_get_current_cipher(ssl)
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
    lastError="SSL_do_handshake error=" || ec || " " || context~errorText
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
    lastError="SSL_read error=" || ec || " " || context~errorText; return .nil
  end
  lastError="SSL_read retry limit exhausted"; return .nil
::method writeAll
  expose context tls ssl lastError config
  use strict arg data
  offset=1; total=data~length
  do while offset<=total
    n=total-offset+1; if n>16384 then n=16384
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
      lastError="SSL_write error=" || ec || " " || context~errorText; return .false
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
::method uninit
  self~close

::class ApiH2Codec public
::method requestHeaders class
  use strict arg request
  headers=.directory~new
  do k over request~headers; headers[k~string~lower]=request~headers[k]~string; end
  if request~body~string<>"" & headers~at("content-length")==.nil then headers["content-length"]=request~body~string~length~string
  text=""
  keys=.array~new; do k over headers; keys~append(k); end; keys~sort
  do k over keys
    name=k~string~lower
    if name="host" | name="connection" | name="transfer-encoding" then iterate
    text=text || name || ": " || headers[k] || "0a"x
  end
  return text
::method parseHeaders class
  use strict arg text
  d=.directory~new
  lines=text~makeArray("0a"x)
  do i=1 to lines~items
    line=lines[i]; if line="" then iterate
    p=line~pos(":"); if p<=1 then iterate
    name=line~left(p-1)~strip~lower; value=line~substr(p+1)~strip
    old=d~at(name); if old==.nil then d[name]=value; else d[name]=old || ", " || value
  end
  return d

::class ApiHttpsTransport subclass ApiTransport public
::attribute config get
::method init
  expose config tlsContext
  use strict arg configArg
  config=configArg~validate
  tlsContext=.ApiTlsClientContext~new(config)
::method execute
  expose config
  use strict arg request,session=.nil
  current=request; redirects=0; seen=.directory~new
  do forever
    canonical=.ApiUrl~new(current~url)~absolute
    if seen~at(canonical~lower)<>.nil then return self~redirectFailure(request,current,.nil,"REDIRECT_LOOP",canonical,redirects)
    seen[canonical~lower]=.true
    response=self~executeOnce(current,session)
    response~finalUrl=canonical; response~redirectCount=redirects
    if response~errorCode<>"" then return response
    if \config~followRedirects then return response
    if \self~isRedirect(response~status) then return response
    location=.ApiHttpCodec~headerValue(response~headers,"location","")
    if location="" then return self~redirectFailure(request,current,response,"REDIRECT_LOCATION_MISSING","",redirects)
    if redirects>=config~maxRedirects then return self~redirectFailure(request,current,response,"REDIRECT_LIMIT",location,redirects)
    oldUrl=.ApiUrl~new(current~url); newUrl=oldUrl~resolve(location)
    if oldUrl~scheme="https" & newUrl~scheme="http" & \config~allowHttpsDowngrade then return self~redirectFailure(request,current,response,"REDIRECT_DOWNGRADE_FORBIDDEN",newUrl~absolute,redirects)
    cross=\oldUrl~sameOrigin(newUrl)
    if cross & \config~allowCrossOriginRedirects then return self~redirectFailure(request,current,response,"REDIRECT_CROSS_ORIGIN_FORBIDDEN",newUrl~absolute,redirects)
    current=self~redirectRequest(current,response~status,newUrl,cross)
    redirects+=1
  end
::method isRedirect private
  use strict arg status
  return status=301 | status=302 | status=303 | status=307 | status=308
::method redirectRequest private
  expose config
  use strict arg request,status,newUrl,crossOrigin
  method=request~method; body=request~body
  if status=303 & method<>"HEAD" then do; method="GET"; body=""; end
  if (status=301 | status=302) & method="POST" & config~legacyPostRedirectToGet then do; method="GET"; body=""; end
  headers=.directory~new
  do k over request~headers
    name=k~string~lower
    if crossOrigin & (name="authorization" | name="proxy-authorization" | name="cookie") then iterate
    if body="" & (name="content-length" | name="transfer-encoding") then iterate
    headers[k]=request~headers[k]
  end
  return .ApiRequest~new(request~id,method,newUrl~absolute,headers,body,request~trafficClass,request~priority,request~expectedMicroWlu,request~requestedRateMicroWluPerSecond,request~callbackName,request~metadata,request~routeRequirement,request~originNodeId)
::method redirectFailure private
  use strict arg original,current,response,code,detail="",count=0
  headers=.directory~new; status=0; version=""
  if response<>.nil then do; headers=response~headers; status=response~status; version=response~httpVersion; end
  if detail<>"" then headers["x-oorexx-transport-detail"]=detail
  return .ApiResponse~new(original~id,status,headers,"",0,code,0,"","",current~url,version,count)
::method executeOnce private
  expose config tlsContext
  use strict arg request,session=.nil
  started=.dateTime~new~microseconds
  signal on syntax name requestFailure
  url=.ApiUrl~new(request~url)
  if url~scheme<>"https" then return self~failed(request,started,"HTTPS_REQUIRED","",url~absolute)
  sock=.Socket~new("AF_INET","SOCK_STREAM","IPPROTO_TCP")
  address=.InetAddress~new(url~host,url~port)
  rc=sock~connect(address)
  if rc<>0 then do; code="CONNECT_FAILED"; detail="errno=" || sock~errno; sock~close; return self~failed(request,started,code,detail,url~absolute); end
  if sock~ioctl("FIONBIO",1)==.nil then do; code="SOCKET_NONBLOCK_FAILED"; detail="errno=" || sock~errno; sock~close; return self~failed(request,started,code,detail,url~absolute); end
  tls=.ApiTlsClientSession~new(tlsContext,sock,url~host,config)
  if \tls~handshake then do; detail=tls~lastError; tls~close; sock~close; return self~failed(request,started,"TLS_HANDSHAKE_FAILED",detail,url~absolute); end
  negotiated=tls~applicationProtocol
  if config~httpVersionPolicy="HTTP2_REQUIRED" & negotiated<>"h2" then do; tls~close; sock~close; return self~failed(request,started,"HTTP2_NEGOTIATION_REQUIRED",negotiated,url~absolute); end
  if negotiated="h2" then response=self~executeH2(request,url,tls,started)
  else response=self~executeHttp11(request,url,tls,started)
  tls~close; sock~close
  return response
requestFailure:
  detail=condition("D")
  if symbol("tls")="VAR" then if tls<>.nil then tls~close
  if symbol("sock")="VAR" then if sock<>.nil then sock~close
  return self~failed(request,started,"TRANSPORT_EXCEPTION",detail,request~url)
::method executeHttp11 private
  expose config
  use strict arg request,url,tls,started
  wire=.ApiHttpCodec~buildRequest(request,url,config)
  if \tls~writeAll(wire) then return self~failed(request,started,"WRITE_FAILED",tls~lastError,url~absolute,"HTTP/1.1")
  raw=""; head=.nil
  do while head==.nil
    chunk=tls~read
    if chunk==.nil then return self~failed(request,started,"READ_FAILED",tls~lastError,url~absolute,"HTTP/1.1")
    if chunk="" then return self~failed(request,started,"TRUNCATED_RESPONSE","peer closed before response headers",url~absolute,"HTTP/1.1")
    raw=raw || chunk
    if raw~length>config~maxHeaderBytes then return self~failed(request,started,"HEADERS_TOO_LARGE",config~maxHeaderBytes,url~absolute,"HTTP/1.1")
    head=.ApiHttpParser~parseHead(raw)
  end
  body=head~bodyPrefix
  transfer=.ApiHttpCodec~headerValue(head~headers,"transfer-encoding","")
  lengthText=.ApiHttpCodec~headerValue(head~headers,"content-length","")
  if .ApiHttpCodec~hasToken(transfer,"chunked") then do
    do forever
      chunk=tls~read
      if chunk==.nil then return self~failed(request,started,"READ_FAILED",tls~lastError,url~absolute,"HTTP/1.1")
      if chunk="" then leave
      body=body || chunk
      if body~length>config~maxBodyBytes+config~maxHeaderBytes then return self~failed(request,started,"BODY_TOO_LARGE",config~maxBodyBytes,url~absolute,"HTTP/1.1")
    end
    body=.ApiHttpParser~decodeChunked(body,config~maxBodyBytes)
  end
  else if lengthText<>"" & datatype(lengthText,"W") then do
    wanted=lengthText+0
    if wanted>config~maxBodyBytes then return self~failed(request,started,"BODY_TOO_LARGE",wanted,url~absolute,"HTTP/1.1")
    do while body~length<wanted
      chunk=tls~read(wanted-body~length)
      if chunk==.nil then return self~failed(request,started,"READ_FAILED",tls~lastError,url~absolute,"HTTP/1.1")
      if chunk="" then leave
      body=body || chunk
    end
    if body~length<wanted then return self~failed(request,started,"TRUNCATED_RESPONSE","expected " || wanted || " bytes got " || body~length,url~absolute,"HTTP/1.1")
    if body~length>wanted then body=body~left(wanted)
  end
  else do
    do forever
      chunk=tls~read
      if chunk==.nil then return self~failed(request,started,"READ_FAILED",tls~lastError,url~absolute,"HTTP/1.1")
      if chunk="" then leave
      body=body || chunk
      if body~length>config~maxBodyBytes then return self~failed(request,started,"BODY_TOO_LARGE",config~maxBodyBytes,url~absolute,"HTTP/1.1")
    end
  end
  elapsed=(.dateTime~new~microseconds-started)%1000
  return .ApiResponse~new(request~id,head~status,head~headers,body,elapsed,"",0,"","",url~absolute,"HTTP/1.1",0)
::method executeH2 private
  expose config tlsContext
  use strict arg request,url,tls,started
  h2=tlsContext~h2Library
  if h2==.nil then return self~failed(request,started,"HTTP2_BRIDGE_UNAVAILABLE","",url~absolute,"h2")
  client=h2~h2_client_new
  if client==.nil then return self~failed(request,started,"HTTP2_SESSION_FAILED","nghttp2 client allocation failed",url~absolute,"h2")
  hdr=.ApiH2Codec~requestHeaders(request); body=request~body~string
  sid=h2~h2_submit(client,request~method,url~scheme,url~authority,url~target,hdr,body,body~length)
  if sid<0 then do; h2~closeObject(client); return self~failed(request,started,"HTTP2_SUBMIT_FAILED",h2~h2_error_string(sid),url~absolute,"h2"); end
  out=.foreign~buffer(65536)
  do forever
    n=h2~h2_next_output(client,out,65536)
    if n<0 then do; out~close; h2~closeObject(client); return self~failed(request,started,"HTTP2_ENCODE_FAILED",h2~h2_error_string(n),url~absolute,"h2"); end
    if n=0 then leave
    if \tls~writeAll(out~bytes~substr(1,n)) then do; out~close; h2~closeObject(client); return self~failed(request,started,"WRITE_FAILED",tls~lastError,url~absolute,"h2"); end
  end
  do while h2~h2_complete(client)=0
    chunk=tls~read
    if chunk==.nil then do; out~close; h2~closeObject(client); return self~failed(request,started,"READ_FAILED",tls~lastError,url~absolute,"h2"); end
    if chunk="" then do; out~close; h2~closeObject(client); return self~failed(request,started,"TRUNCATED_RESPONSE","HTTP/2 stream closed before END_STREAM",url~absolute,"h2"); end
    used=h2~h2_feed(client,chunk,chunk~length)
    if used<0 then do; out~close; h2~closeObject(client); return self~failed(request,started,"HTTP2_DECODE_FAILED",h2~h2_error_string(used),url~absolute,"h2"); end
    do forever
      n=h2~h2_next_output(client,out,65536)
      if n<0 then do; out~close; h2~closeObject(client); return self~failed(request,started,"HTTP2_ENCODE_FAILED",h2~h2_error_string(n),url~absolute,"h2"); end
      if n=0 then leave
      if \tls~writeAll(out~bytes~substr(1,n)) then do; out~close; h2~closeObject(client); return self~failed(request,started,"WRITE_FAILED",tls~lastError,url~absolute,"h2"); end
    end
    if h2~h2_body_length(client)>config~maxBodyBytes | h2~h2_headers_length(client)>config~maxHeaderBytes then do; out~close; h2~closeObject(client); return self~failed(request,started,"HTTP2_RESPONSE_TOO_LARGE","configured response bounds exceeded",url~absolute,"h2"); end
  end
  status=h2~h2_status(client); streamError=h2~h2_stream_error(client)
  if streamError<>0 then do; out~close; h2~closeObject(client); return self~failed(request,started,"HTTP2_STREAM_ERROR",streamError,url~absolute,"h2"); end
  hn=h2~h2_headers_length(client); headers=.directory~new
  if hn>0 then do; hb=.foreign~buffer(hn); got=h2~h2_copy_headers(client,hb,hn); headers=.ApiH2Codec~parseHeaders(hb~bytes~substr(1,got)); hb~close; end
  bn=h2~h2_body_length(client); body=""
  if bn>0 then do; bb=.foreign~buffer(bn); got=h2~h2_copy_body(client,bb,bn); body=bb~bytes~substr(1,got); bb~close; end
  out~close; h2~closeObject(client)
  elapsed=(.dateTime~new~microseconds-started)%1000
  return .ApiResponse~new(request~id,status,headers,body,elapsed,"",0,"","",url~absolute,"h2",0)
::method failed private
  use strict arg request,started,code,detail="",finalUrl="",version=""
  headers=.directory~new
  if detail<>"" then headers["x-oorexx-transport-detail"]=detail
  elapsed=(.dateTime~new~microseconds-started)%1000
  return .ApiResponse~new(request~id,0,headers,"",elapsed,code,0,"","",finalUrl,version,0)
::method close
  expose tlsContext
  if tlsContext<>.nil then do; tlsContext~close; tlsContext=.nil; end
::method uninit
  self~close

::requires "ApiClient.cls"
::requires "socket.cls"
::requires "foreign.cls"
