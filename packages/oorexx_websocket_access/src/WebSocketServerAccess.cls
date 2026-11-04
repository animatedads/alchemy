/* WebSocketServerAccess.cls
 * ooRexx WebSocket Access v0.1-dev4 server-side RFC 6455 access.
 *
 * Consumes an already accepted plaintext stream. When composed with the owned
 * HTTPS server, that stream is a TLS-plaintext upgrade wrapper; Socket/TLS
 * objects remain owned by HTTPS/SocketProvider and are never exposed here.
 */

::class WebSocketServerOptions public
::method init
  expose expectedPath allowedOrigins subprotocols maximumHeaderBytes maximumMessageBytes
  use strict arg expectedPath="", allowedOrigins=.nil, subprotocols=.nil, maximumHeaderBytes=65536, maximumMessageBytes=16777216
  if expectedPath<>"" & left(expectedPath,1)<>"/" then raise syntax 88.900 array("WebSocket server path must start with /")
  if allowedOrigins=.nil then allowedOrigins=.array~new
  if subprotocols=.nil then subprotocols=.array~new
  maximumHeaderBytes=maximumHeaderBytes+0
  maximumMessageBytes=maximumMessageBytes+0
  if maximumHeaderBytes<1024 then raise syntax 88.900 array("WebSocket server header limit too small")
  if maximumMessageBytes<1 then raise syntax 88.900 array("WebSocket server message limit must be positive")
::attribute expectedPath get
::attribute allowedOrigins get
::attribute subprotocols get
::attribute maximumHeaderBytes get
::attribute maximumMessageBytes get

::class WebSocketUpgradeRequest public
::method init
  expose method path version headers rawRequest
  use strict arg method, path, version="HTTP/1.1", headers=.nil, rawRequest=""
  if headers=.nil then headers=.directory~new
::attribute method get
::attribute path get
::attribute version get
::attribute headers get
::attribute rawRequest get
::method header
  expose headers
  use strict arg name
  return headers[lower(name)]

::class WebSocketServerHandshakeResult public
::method init
  expose path headers subprotocol origin rawRequest
  use strict arg path, headers, subprotocol="", origin="", rawRequest=""
::attribute path get
::attribute headers get
::attribute subprotocol get
::attribute origin get
::attribute rawRequest get

::class WebSocketServerConnection public
::method init
  expose stream socketAddress state subprotocol handshake receiveBuffer fragmentOpcode fragmentPayload maximumMessageBytes
  use strict arg stream, socketAddress, handshake, maximumMessageBytes=16777216, initialReceiveBuffer=""
  subprotocol=handshake~subprotocol
  state=.WebSocketState~OPEN
  receiveBuffer=initialReceiveBuffer
  fragmentOpcode=.nil
  fragmentPayload=""
  maximumMessageBytes=maximumMessageBytes+0
::attribute socketAddress get
::attribute subprotocol get
::attribute handshake get
::method state
  expose state
  return state
::method rawStream
  expose stream
  return stream

::method sendMessage
  expose state
  use strict arg message
  if state<>.WebSocketState~OPEN then return .false
  return self~sendFrame(message)

::method sendFrame private
  expose stream state
  use strict arg message
  if state=.WebSocketState~CLOSED then return .false
  return stream~write(.WebSocketCodec~encodeServer(message))

::method sendControl private
  use strict arg opcode, payload=""
  return self~sendFrame(.WebSocketMessage~new(opcode,payload,.true))

::method sendText
  use strict arg text
  return self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~TEXT,text,.true))

::method sendBinary
  use strict arg bytes
  return self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~BINARY,bytes,.true))

::method receive
  expose stream receiveBuffer state fragmentOpcode fragmentPayload maximumMessageBytes
  use strict arg maximumRead=65536
  if state=.WebSocketState~CLOSED then return .nil
  do forever
    signal on syntax name decodeFailure
    parsed=.WebSocketCodec~decodeClient(receiveBuffer)
    signal off syntax
    if parsed<>.nil then do
      receiveBuffer=substr(receiveBuffer,parsed["consumed"]+1)
      msg=parsed["message"]

      if msg~opcode=.WebSocketOpcode~PING then do
        ignore=self~sendControl(.WebSocketOpcode~PONG,msg~payload)
        iterate
      end
      if msg~opcode=.WebSocketOpcode~PONG then return msg
      if msg~opcode=.WebSocketOpcode~CLOSE then do
        if state=.WebSocketState~OPEN then do
          state=.WebSocketState~CLOSING
          ignore=self~sendControl(.WebSocketOpcode~CLOSE,msg~payload)
        end
        ignore=stream~close
        state=.WebSocketState~CLOSED
        fragmentOpcode=.nil
        fragmentPayload=""
        return msg
      end

      if msg~opcode=.WebSocketOpcode~CONTINUATION then do
        if fragmentOpcode=.nil then return self~protocolFailure(1002,"unexpected continuation frame")
        fragmentPayload=fragmentPayload||msg~payload
        if length(fragmentPayload)>maximumMessageBytes then return self~protocolFailure(1009,"WebSocket message exceeds configured limit")
        if msg~final then do
          completed=.WebSocketMessage~new(fragmentOpcode,fragmentPayload,.true)
          fragmentOpcode=.nil
          fragmentPayload=""
          return completed
        end
        iterate
      end

      if msg~opcode=.WebSocketOpcode~TEXT | msg~opcode=.WebSocketOpcode~BINARY then do
        if fragmentOpcode<>.nil then return self~protocolFailure(1002,"new data frame while fragmented message active")
        if length(msg~payload)>maximumMessageBytes then return self~protocolFailure(1009,"WebSocket message exceeds configured limit")
        if msg~final then return msg
        fragmentOpcode=msg~opcode
        fragmentPayload=msg~payload
        iterate
      end
      return self~protocolFailure(1002,"unsupported WebSocket frame sequence")
    end

    chunk=stream~read(maximumRead)
    if chunk=.nil | chunk="" then return .nil
    receiveBuffer=receiveBuffer||chunk
  end

decodeFailure:
  signal off syntax
  return self~protocolFailure(1002,"invalid client WebSocket frame")

::method protocolFailure private
  expose stream state fragmentOpcode fragmentPayload
  use strict arg code, reason
  if state<>.WebSocketState~CLOSED then do
    state=.WebSocketState~CLOSING
    ignore=self~sendControl(.WebSocketOpcode~CLOSE,.WebSocketCodec~uintBytes(code,2)||reason)
    ignore=stream~close
    state=.WebSocketState~CLOSED
  end
  fragmentOpcode=.nil
  fragmentPayload=""
  return .nil

::method close
  expose stream state fragmentOpcode fragmentPayload
  use strict arg code=1000, reason=""
  if state=.WebSocketState~CLOSED then return .true
  if state=.WebSocketState~OPEN then do
    state=.WebSocketState~CLOSING
    ignore=self~sendControl(.WebSocketOpcode~CLOSE,.WebSocketCodec~uintBytes(code,2)||reason)
  end
  ignore=stream~close
  state=.WebSocketState~CLOSED
  fragmentOpcode=.nil
  fragmentPayload=""
  return .true

::class WebSocketServerAccess public
::method init
  expose handshakeCrypto
  use strict arg handshakeCrypto
  if handshakeCrypto=.nil then raise syntax 88.900 array("WebSocket handshake crypto authority is required")

::method accept
  use strict arg listener, options=.nil
  stream=listener~accept
  if stream=.nil then return .nil
  return self~acceptStream(stream,stream~socketAddress,options)

::method acceptStream
  use strict arg stream, socketAddress, options=.nil
  if options=.nil then options=.WebSocketServerOptions~new
  headerRead=self~readHttpHeaders(stream,options~maximumHeaderBytes)
  if headerRead=.nil then do
    ignore=stream~close
    return .nil
  end
  request=self~parseRequest(headerRead["raw"])
  if request=.nil then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end
  return self~acceptParsedRequest(stream,socketAddress,request,options,headerRead["remainder"])

::method acceptParsedRequest
  expose handshakeCrypto
  use strict arg stream, socketAddress, request, options=.nil, initialReceiveBuffer=""
  if options=.nil then options=.WebSocketServerOptions~new
  if request=.nil | request~isA(.WebSocketUpgradeRequest)=.false then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end
  if request~method<>"GET" | request~version<>"HTTP/1.1" then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end
  if options~expectedPath<>"" & request~path<>options~expectedPath then do
    self~reject(stream,404,"Not Found")
    return .nil
  end
  if lower(request~header("upgrade"))<>"websocket" | self~headerHasToken(request~header("connection"),"upgrade")=.false then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end
  if request~header("sec-websocket-version")<>"13" then do
    response="HTTP/1.1 426 Upgrade Required"||"0d0a"x||,
             "Sec-WebSocket-Version: 13"||"0d0a"x||,
             "Connection: close"||"0d0a0d0a"x
    ignore=stream~write(response)
    ignore=stream~close
    return .nil
  end

  key=request~header("sec-websocket-key")
  if key=.nil then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end
  key=strip(key)
  if self~validClientKey(key)=.false then do
    self~reject(stream,400,"Bad Request")
    return .nil
  end

  origin=""
  if request~header("origin")<>.nil then origin=request~header("origin")
  if options~allowedOrigins~items>0 then do
    allowed=.false
    do o over options~allowedOrigins
      if o=origin then allowed=.true
    end
    if allowed=.false then do
      self~reject(stream,403,"Forbidden")
      return .nil
    end
  end

  selected=self~selectSubprotocol(request~header("sec-websocket-protocol"),options~subprotocols)
  accept=handshakeCrypto~expectedAccept(key)
  if accept="" then do
    self~reject(stream,500,"Internal Server Error")
    return .nil
  end

  response="HTTP/1.1 101 Switching Protocols"||"0d0a"x||,
           "Upgrade: websocket"||"0d0a"x||,
           "Connection: Upgrade"||"0d0a"x||,
           "Sec-WebSocket-Accept: "||accept||"0d0a"x
  if selected<>"" then response=response||"Sec-WebSocket-Protocol: "||selected||"0d0a"x
  response=response||"0d0a"x
  if stream~write(response)=.false then do
    ignore=stream~close
    return .nil
  end

  result=.WebSocketServerHandshakeResult~new(request~path,request~headers,selected,origin,request~rawRequest)
  return .WebSocketServerConnection~new(stream,socketAddress,result,options~maximumMessageBytes,initialReceiveBuffer)

::method readHttpHeaders private
  use strict arg stream, maximumBytes
  data=""
  marker="0d0a0d0a"x
  do while pos(marker,data)=0
    chunk=stream~read(4096)
    if chunk=.nil | chunk="" then return .nil
    data=data||chunk
    if length(data)>maximumBytes then return .nil
  end
  endPos=pos(marker,data)+3
  out=.directory~new
  out["raw"]=left(data,endPos)
  out["remainder"]=substr(data,endPos+1)
  return out

::method parseRequest private
  use strict arg raw
  lines=raw~makeArray("0d0a"x)
  if lines~items<1 then return .nil
  first=lines[1]~makeArray(" ")
  if first~items<>3 then return .nil
  headers=.directory~new
  do i=2 to lines~items
    line=lines[i]
    if line="" then leave
    p=pos(":",line)
    if p=0 then return .nil
    name=lower(strip(left(line,p-1)))
    value=strip(substr(line,p+1))
    if headers[name]=.nil then headers[name]=value
    else headers[name]=headers[name]||", "||value
  end
  return .WebSocketUpgradeRequest~new(first[1],first[2],first[3],headers,raw)

::method headerHasToken private
  use strict arg value, wanted
  if value=.nil then return .false
  parts=value~makeArray(",")
  do p over parts
    if lower(strip(p))=lower(wanted) then return .true
  end
  return .false

::method validClientKey private
  use strict arg key
  if length(key)<>24 then return .false
  if right(key,2)<>"==" then return .false
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  do i=1 to 22
    if pos(substr(key,i,1),alphabet)=0 then return .false
  end
  return .true

::method selectSubprotocol private
  use strict arg offered, supported
  if offered=.nil | strip(offered)="" | supported~items=0 then return ""
  offers=offered~makeArray(",")
  do offer over offers
    candidate=strip(offer)
    do serverProtocol over supported
      if candidate=serverProtocol then return candidate
    end
  end
  return ""

::method reject private
  use strict arg stream, code, reason
  response="HTTP/1.1 "||code||" "||reason||"0d0a"x||,
           "Connection: close"||"0d0a"x||,
           "Content-Length: 0"||"0d0a0d0a"x
  ignore=stream~write(response)
  ignore=stream~close
  return .false

::requires "WebSocketAccess.cls"
