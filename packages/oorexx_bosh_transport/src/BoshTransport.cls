/* BoshTransport.cls
 * ooRexx BOSH Transport v0.1-dev5
 *
 * BOSH is a lower-layer logical-stream carrier.  This package has no XMPP
 * dependency.  It consumes an injected HTTP exchange provider and exposes
 * ordered logical stream send/receive semantics to upper protocols.
 */

::class BoshBuild public
::constant VERSION "0.1-dev5"
::constant API "bosh.transport/0.1"
::constant HTTPBIND_NS "http://jabber.org/protocol/httpbind"

::class BoshState public
::constant NEW "NEW"
::constant OPEN "OPEN"
::constant TERMINATING "TERMINATING"
::constant CLOSED "CLOSED"
::constant FAILED "FAILED"

::class BoshEndpoint public
::method init
  expose uri targetDomain language waitSeconds holdRequests metadata
  use strict arg uri, targetDomain="", language="en", waitSeconds=60, holdRequests=1, metadata=.nil
  uri=uri~string~strip
  if uri="" then raise syntax 88.900 array("BOSH endpoint requires URI")
  targetDomain=targetDomain~string~strip
  language=language~string~strip
  waitSeconds=waitSeconds+0
  holdRequests=holdRequests+0
  if waitSeconds<1 then raise syntax 88.900 array("BOSH wait must be positive")
  if holdRequests<0 then raise syntax 88.900 array("BOSH hold must not be negative")
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute uri get
::attribute targetDomain get
::attribute language get
::attribute waitSeconds get
::attribute holdRequests get
::attribute metadata get

/* HTTP authority is injected.  Expected operation:
 *   exchange(uri, method, headers, body) -> response object
 * Response object must expose statusCode, body and optionally metadata.
 */
::class BoshHttpExchangeProvider public
::method exchange abstract

::class BoshHttpResponse public
::method init
  expose statusCode body metadata
  use strict arg statusCode, body="", metadata=.nil
  statusCode=statusCode+0
  body=body~string
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute statusCode get
::attribute body get
::attribute metadata get

::class BoshBodyCodec public
::method escapeAttribute class
  use strict arg value
  value=value~string
  value=changestr("&",value,"&amp;")
  value=changestr("'",value,"&apos;")
  value=changestr('"',value,"&quot;")
  value=changestr("<",value,"&lt;")
  value=changestr(">",value,"&gt;")
  return value

::method createRequest class
  use strict arg rid, endpoint, payload="", extraAttributes=.nil
  s="<body rid='"rid"' xmlns='".BoshBuild~HTTPBIND_NS"'"
  if endpoint~targetDomain<>"" then s=s" to='"self~escapeAttribute(endpoint~targetDomain)"'"
  if endpoint~language<>"" then s=s" xml:lang='"self~escapeAttribute(endpoint~language)"'"
  s=s" wait='"endpoint~waitSeconds"' hold='"endpoint~holdRequests"' ver='1.6'"
  s=self~appendExtraAttributes(s,extraAttributes)
  return s">"||payload||"</body>"

::method sessionRequest class
  use strict arg rid, sid, payload="", requestType="", extraAttributes=.nil
  s="<body rid='"rid"' sid='"self~escapeAttribute(sid)"' xmlns='".BoshBuild~HTTPBIND_NS"'"
  if requestType<>"" then s=s" type='"self~escapeAttribute(requestType)"'"
  s=self~appendExtraAttributes(s,extraAttributes)
  return s">"||payload||"</body>"

/* Upper-protocol bindings occasionally need namespaced attributes on BOSH
 * request bodies.  The BOSH package transports those attributes without
 * interpreting them.  Core BOSH control attributes remain protected so a
 * binding cannot overwrite RID/SID/session semantics. */
::method appendExtraAttributes class
  use strict arg s, extraAttributes=.nil
  if extraAttributes=.nil then return s
  if \extraAttributes~isA(.Directory) then raise syntax 88.900 array("BOSH extra attributes must be a Directory")
  do name over extraAttributes
    key=name~string~strip
    if \self~validAttributeName(key) then raise syntax 88.900 array("invalid BOSH extension attribute name: "||key)
    upper=translate(key)
    if pos("|"||upper||"|","|RID|SID|XMLNS|TO|WAIT|HOLD|VER|TYPE|XML:LANG|")>0 then -
      raise syntax 88.900 array("BOSH extension cannot replace reserved attribute: "||key)
    s=s" "||key||"='"||self~escapeAttribute(extraAttributes[name])||"'"
  end
  return s

::method validAttributeName class
  use strict arg name
  if name="" then return .false
  first=substr(name,1,1)
  if pos(first,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_:")=0 then return .false
  allowed="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.:-"
  do i=2 to length(name)
    if pos(substr(name,i,1),allowed)=0 then return .false
  end
  return .true

::method attribute class
  use strict arg xml, name
  marker=name"='"
  p=pos(marker,xml)
  quote="'"
  if p=0 then do
    marker=name'="'
    p=pos(marker,xml)
    quote='"'
  end
  if p=0 then return ""
  p=p+length(marker)
  q=pos(quote,xml,p)
  if q=0 then return ""
  return substr(xml,p,q-p)

::method innerPayload class
  use strict arg xml
  p=pos(">",xml)
  if p=0 then return ""
  q=lastpos("</body>",xml)
  if q=0 | q<=p then return ""
  return substr(xml,p+1,q-p-1)

/* The request-id source is injected to keep randomness/entropy policy out of
 * the BOSH protocol package.  It must return a positive whole number. */
::class BoshRequestIdSource public
::method nextInitial abstract

::class BoshFixedRequestIdSource public subclass BoshRequestIdSource
::method init
  expose initial
  use strict arg initialRid
  initial=initialRid+0
::method nextInitial
  expose initial
  return initial

/* Optional observation seam.  The BOSH core emits operational facts but owns
 * no telemetry store or metric vocabulary.  Estate Instrumentation Mesh support
 * is supplied by BoshInstrumentationAdapter.cls. */
::class BoshObserver public
::method sessionOpenAttempt; return .true
::method sessionOpened; use strict arg waitSeconds, holdRequests; return .true
::method sessionOpenFailed; use strict arg reason; return .true
::method sessionClosed; return .true
::method sessionFailed; use strict arg reason; return .true
::method httpExchangeStarted; use strict arg requestBytes; return .true
::method httpExchangeCompleted; use strict arg statusCode, responseBytes; return .true
::method httpExchangeFailed; use strict arg reason, statusCode=0, responseBytes=0; return .true

::class BoshSession public
::method init
  expose endpoint http ridSource state rid sid waitSeconds holdRequests lastError observer outstanding openPayload
  use strict arg endpoint, httpExchangeProvider, requestIdSource, observation=.nil
  endpoint=endpoint
  http=httpExchangeProvider
  ridSource=requestIdSource
  state=.BoshState~NEW
  rid=0
  sid=""
  waitSeconds=endpoint~waitSeconds
  holdRequests=endpoint~holdRequests
  lastError=""
  if observation=.nil then observer=.BoshObserver~new
  else observer=observation
  outstanding=0
  openPayload=""
::attribute state get
::attribute sid get
::attribute rid get
::attribute lastError get
::attribute waitSeconds get
::attribute holdRequests get
::attribute openPayload get

::method open
  expose endpoint http ridSource state rid sid waitSeconds holdRequests lastError observer openPayload
  use strict arg extraAttributes=.nil
  if state<>.BoshState~NEW then return .false
  ignore=observer~sessionOpenAttempt
  rid=ridSource~nextInitial+0
  if rid<1 | \datatype(rid,"W") then do
    state=.BoshState~FAILED; lastError="invalid initial request id"; ignore=observer~sessionOpenFailed(lastError); return .false
  end
  request=.BoshBodyCodec~createRequest(rid,endpoint,"",extraAttributes)
  response=self~post(request)
  if response=.nil then return .false
  sid=.BoshBodyCodec~attribute(response~body,"sid")
  if sid="" then do
    state=.BoshState~FAILED; lastError="BOSH session response omitted sid"; ignore=observer~sessionOpenFailed(lastError); return .false
  end
  serverWait=.BoshBodyCodec~attribute(response~body,"wait")
  if serverWait<>"" & datatype(serverWait,"W") then waitSeconds=serverWait+0
  openPayload=.BoshBodyCodec~innerPayload(response~body)
  state=.BoshState~OPEN
  ignore=observer~sessionOpened(waitSeconds,holdRequests)
  return .true

::method send
  use strict arg payload
  return self~exchange(payload)

/* Generic upper-protocol exchange.  Extra request attributes are transported
 * opaquely; BOSH itself assigns no semantics to them. */
::method exchange
  expose state rid sid
  use strict arg payload="", extraAttributes=.nil
  if state<>.BoshState~OPEN then return .false
  rid=rid+1
  response=self~post(.BoshBodyCodec~sessionRequest(rid,sid,payload,"",extraAttributes))
  if response=.nil then return .false
  return .BoshBodyCodec~innerPayload(response~body)

/* An empty body is a legitimate BOSH request used to wait for inbound data. */
::method receive
  return self~exchange("")

::method terminate
  expose state rid sid observer
  use strict arg finalPayload=""
  if state=.BoshState~CLOSED then return .true
  if state<>.BoshState~OPEN then return .false
  state=.BoshState~TERMINATING
  rid=rid+1
  response=self~post(.BoshBodyCodec~sessionRequest(rid,sid,finalPayload,"terminate"))
  if response=.nil then return .false
  state=.BoshState~CLOSED
  ignore=observer~sessionClosed
  return .true

::method post private
  expose endpoint http state lastError observer outstanding
  use strict arg requestBody
  headers=.directory~new
  headers["content-type"]="text/xml; charset=utf-8"
  headers["accept"]="text/xml, application/xml"

  outstanding+=1
  ignore=observer~httpExchangeStarted(length(requestBody))

  response=http~exchange(endpoint~uri,"POST",headers,requestBody)
  outstanding-=1
  if response=.nil then do
    state=.BoshState~FAILED; lastError="HTTP exchange returned no response"
    ignore=observer~httpExchangeFailed(lastError)
    ignore=observer~sessionFailed(lastError)
    return .nil
  end
  if response~statusCode<>200 then do
    state=.BoshState~FAILED; lastError="HTTP status "response~statusCode
    ignore=observer~httpExchangeFailed(lastError,response~statusCode,length(response~body))
    ignore=observer~sessionFailed(lastError)
    return .nil
  end
  ignore=observer~httpExchangeCompleted(response~statusCode,length(response~body))
  return response

/* Provider shape suitable for registration at a lower logical-stream selector.
 * It intentionally exposes no XMPP concepts. */
::class BoshStreamProvider public
::method init
  expose http ridSource observer
  use strict arg httpExchangeProvider, requestIdSource, observation=.nil
  http=httpExchangeProvider
  ridSource=requestIdSource
  observer=observation
::method scheme
  return "bosh"
::method capabilities
  d=.directory~new
  d["ORDERED"]=.true
  d["RELIABLE"]=.true
  d["BIDIRECTIONAL"]=.true
  d["LOGICAL_PERSISTENCE"]=.true
  d["HTTP_CARRIER"]=.true
  return d
::method connect
  expose http ridSource observer
  use strict arg endpoint, initialAttributes=.nil
  session=.BoshSession~new(endpoint,http,ridSource,observer)
  if \session~open(initialAttributes) then return .nil
  return .BoshLogicalStream~new(session,session~openPayload)

::class BoshLogicalStream public
::method init
  expose session receiveBuffer closed
  use strict arg boshSession, initialPayload=""
  session=boshSession
  receiveBuffer=initialPayload
  closed=.false
::attribute session get

/* Stream-style SEND returns bytes accepted.  Any BOSH response payload arriving
 * on the corresponding HTTP exchange is retained for subsequent RECV calls. */
::method send
  expose session receiveBuffer closed
  use strict arg bytes
  if closed then return -1
  incoming=session~send(bytes)
  if incoming=.false then return -1
  if incoming<>"" then receiveBuffer=receiveBuffer||incoming
  return length(bytes)

/* RECV never truncates-and-discards.  Partial reads leave the tail buffered. */
::method recv
  expose session receiveBuffer closed
  use strict arg maximumBytes=0
  if closed then return .nil
  if receiveBuffer="" then do
    incoming=session~receive
    if incoming=.nil then return .nil
    receiveBuffer=receiveBuffer||incoming
  end
  if maximumBytes<=0 | maximumBytes>=length(receiveBuffer) then do
    out=receiveBuffer
    receiveBuffer=""
    return out
  end
  out=left(receiveBuffer,maximumBytes)
  receiveBuffer=substr(receiveBuffer,maximumBytes+1)
  return out

::method pendingBytes
  expose receiveBuffer
  return length(receiveBuffer)

::method close
  expose session closed
  if closed then return .true
  ok=session~terminate
  if ok then closed=.true
  return ok

