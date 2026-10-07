/* WebSocketAccess.cls
 * ooRexx WebSocket Access v0.1-dev1
 *
 * RFC 6455 access layer above SocketProvider's SocketStreamAdapter.
 * SocketProvider remains the sole socket acquisition/isolation authority.
 */

::class WebSocketAccessBuild public
::constant VERSION "0.1-dev1"
::constant ACCESS_API "websocket.access/0.1"
::constant MESSAGE_API "websocket.message/0.1"
::constant HANDSHAKE_CRYPTO_API "websocket.handshake.crypto/0.1"
::constant RFC "RFC 6455"

::class WebSocketOpcode public
::constant CONTINUATION 0
::constant TEXT 1
::constant BINARY 2
::constant CLOSE 8
::constant PING 9
::constant PONG 10

::class WebSocketState public
::constant CONNECTING "CONNECTING"
::constant OPEN "OPEN"
::constant CLOSING "CLOSING"
::constant CLOSED "CLOSED"

/* Crypto authority contract. Production providers must return a randomly
 * selected 16-byte client nonce as a Base64 string and the RFC 6455 expected
 * Sec-WebSocket-Accept value for that key. Protocol code owns neither entropy
 * nor digest implementation. */
::class WebSocketHandshakeCrypto public
::method clientKey abstract
::method expectedAccept abstract

/* Mask authority is separated for exactly the same reason. Each client frame
 * needs a fresh unpredictable 32-bit masking key. */
::class WebSocketMaskSource public
::method nextMask abstract

::class WebSocketMessage public
::method init
  expose opcode payload final
  use strict arg opcode, payload="", final=.true
  opcode=opcode+0
  if opcode<0 | opcode>15 then raise syntax 88.900 array("invalid WebSocket opcode")
  payload=payload
  final=final
::attribute opcode get
::attribute payload get
::attribute final get
::method isText
  expose opcode
  return opcode=.WebSocketOpcode~TEXT
::method isBinary
  expose opcode
  return opcode=.WebSocketOpcode~BINARY
::method isControl
  expose opcode
  return opcode>=8

::class WebSocketClientOptions public
::method init
  expose path hostHeader origin subprotocols extraHeaders
  use strict arg path="/", hostHeader="", origin="", subprotocols=.nil, extraHeaders=.nil
  if path="" then path="/"
  if left(path,1)<>"/" then raise syntax 88.900 array("WebSocket path must start with /")
  if subprotocols=.nil then subprotocols=.array~new
  if extraHeaders=.nil then extraHeaders=.directory~new
  path=path
  hostHeader=hostHeader~string
  origin=origin~string
  subprotocols=subprotocols
  extraHeaders=extraHeaders
::attribute path get
::attribute hostHeader get
::attribute origin get
::attribute subprotocols get
::attribute extraHeaders get

::class WebSocketHandshakeResult public
::method init
  expose status headers subprotocol rawResponse
  use strict arg status, headers, subprotocol="", rawResponse=""
  status=status+0
  headers=headers
  subprotocol=subprotocol
  rawResponse=rawResponse
::attribute status get
::attribute headers get
::attribute subprotocol get
::attribute rawResponse get

::class WebSocketCodec public
::method encodeClient class
  use strict arg message, maskBytes
  if message=.nil then raise syntax 88.900 array("WebSocket message required")
  if length(maskBytes)<>4 then raise syntax 88.900 array("WebSocket client mask must be 4 bytes")
  payload=message~payload
  opcode=message~opcode
  if message~isControl then do
    if \message~final then raise syntax 88.900 array("WebSocket control frames must not be fragmented")
    if length(payload)>125 then raise syntax 88.900 array("WebSocket control payload exceeds 125 bytes")
  end
  first=opcode
  if message~final then first=first+128
  header=.WebSocketCodec~byte(first)
  n=length(payload)
  if n<=125 then header=header||.WebSocketCodec~byte(128+n)
  else if n<=65535 then header=header||.WebSocketCodec~byte(254)||.WebSocketCodec~uintBytes(n,2)
  else header=header||.WebSocketCodec~byte(255)||.WebSocketCodec~uintBytes(n,8)
  masked=.WebSocketCodec~applyMask(payload,maskBytes)
  return header||maskBytes||masked

::method decodeServer class
  use strict arg bytes
  parsed=.WebSocketCodec~decodeFrame(bytes,.false)
  if parsed=.nil then return .nil
  return parsed

::method decodeFrame class
  use strict arg bytes, allowMasked=.false
  if length(bytes)<2 then return .nil
  b1=c2d(substr(bytes,1,1)); b2=c2d(substr(bytes,2,1))
  final=(b1%128)=1
  opcode=b1//16
  masked=(b2%128)=1
  n=b2//128
  pos=3
  if n=126 then do
    if length(bytes)<4 then return .nil
    n=.WebSocketCodec~bytesUInt(substr(bytes,3,2)); pos=5
  end
  else if n=127 then do
    if length(bytes)<10 then return .nil
    n=.WebSocketCodec~bytesUInt(substr(bytes,3,8)); pos=11
  end
  mask=""
  if masked then do
    if \allowMasked then raise syntax 88.900 array("server-to-client WebSocket frame must not be masked")
    if length(bytes)<pos+3 then return .nil
    mask=substr(bytes,pos,4); pos+=4
  end
  if length(bytes)<pos+n-1 then return .nil
  payload=substr(bytes,pos,n)
  consumed=pos+n-1
  if masked then payload=.WebSocketCodec~applyMask(payload,mask)
  msg=.WebSocketMessage~new(opcode,payload,final)
  out=.directory~new
  out["message"]=msg
  out["consumed"]=consumed
  return out

::method applyMask class
  use strict arg payload, maskBytes
  if payload="" then return ""
  repeated=""
  needed=length(payload)
  do while length(repeated)<needed
    repeated=repeated||maskBytes
  end
  return bitxor(payload,left(repeated,needed))

::method byte class
  use strict arg n
  n=n+0
  if n<0 | n>255 then raise syntax 88.900 array("byte out of range")
  return x2c(right(d2x(n),2,"0"))

::method uintBytes class
  use strict arg n, width
  n=n+0; width=width+0
  if n<0 then raise syntax 88.900 array("unsigned integer must not be negative")
  hex=d2x(n)
  wanted=width*2
  if length(hex)>wanted then raise syntax 88.900 array("unsigned integer does not fit")
  return x2c(right(hex,wanted,"0"))

::method bytesUInt class
  use strict arg bytes
  if bytes="" then return 0
  return x2d(c2x(bytes))

::class WebSocketConnection public
::method init
  expose stream socketAddress state subprotocol receiveBuffer maskSource handshake
  use strict arg stream, socketAddress, maskSource, handshake
  stream=stream
  socketAddress=socketAddress
  maskSource=maskSource
  handshake=handshake
  state=.WebSocketState~OPEN
  subprotocol=handshake~subprotocol
  receiveBuffer=""
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
  expose stream maskSource state
  use strict arg message
  if state<>.WebSocketState~OPEN then return .false
  mask=maskSource~nextMask
  if length(mask)<>4 then raise syntax 88.900 array("mask source must return exactly 4 bytes")
  frame=.WebSocketCodec~encodeClient(message,mask)
  return stream~write(frame)
::method sendText
  use strict arg text
  return self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~TEXT,text,.true))
::method sendBinary
  use strict arg bytes
  return self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~BINARY,bytes,.true))
::method receive
  expose stream receiveBuffer state
  use strict arg maximumRead=65536
  if state=.WebSocketState~CLOSED then return .nil
  do forever
    parsed=.WebSocketCodec~decodeServer(receiveBuffer)
    if parsed<>.nil then do
      consumed=parsed["consumed"]
      receiveBuffer=substr(receiveBuffer,consumed+1)
      msg=parsed["message"]
      if msg~opcode=.WebSocketOpcode~PING then do
        self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~PONG,msg~payload,.true))
        iterate
      end
      if msg~opcode=.WebSocketOpcode~CLOSE then do
        if state=.WebSocketState~OPEN then do
          state=.WebSocketState~CLOSING
          self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~CLOSE,msg~payload,.true))
        end
        ignore=stream~close
        state=.WebSocketState~CLOSED
      end
      return msg
    end
    chunk=stream~read(maximumRead)
    if chunk=.nil | chunk="" then return .nil
    receiveBuffer=receiveBuffer||chunk
  end
::method close
  expose stream state
  use strict arg code=1000, reason=""
  if state=.WebSocketState~CLOSED then return .true
  if state=.WebSocketState~OPEN then do
    payload=.WebSocketCodec~uintBytes(code,2)||reason
    state=.WebSocketState~CLOSING
    ignore=self~sendMessage(.WebSocketMessage~new(.WebSocketOpcode~CLOSE,payload,.true))
  end
  ignore=stream~close
  state=.WebSocketState~CLOSED
  return .true

::class WebSocketAccess public
::method init
  expose socketProvider handshakeCrypto maskSource
  use strict arg socketProvider, handshakeCrypto, maskSource
  if socketProvider=.nil then raise syntax 88.900 array("SocketProvider is required")
  if handshakeCrypto=.nil then raise syntax 88.900 array("WebSocket handshake crypto authority is required")
  if maskSource=.nil then raise syntax 88.900 array("WebSocket mask authority is required")
  socketProvider=socketProvider
  handshakeCrypto=handshakeCrypto
  maskSource=maskSource
::method connect
  expose socketProvider
  use strict arg logicalName, options=.nil
  stream=socketProvider~streamSender(logicalName)
  if stream=.nil then return .nil
  return self~connectStream(stream,stream~socketAddress,options)
::method connectAt
  expose socketProvider
  use strict arg socketAddress, options=.nil
  stream=socketProvider~streamSenderAt(socketAddress)
  if stream=.nil then return .nil
  return self~connectStream(stream,socketAddress,options)
::method connectStream
  expose handshakeCrypto maskSource
  use strict arg stream, socketAddress, options=.nil
  if options=.nil then options=.WebSocketClientOptions~new
  key=handshakeCrypto~clientKey
  if key="" then raise syntax 88.900 array("handshake crypto returned empty client key")
  host=options~hostHeader
  if host="" then do
    host=socketAddress~host
    if socketAddress~port<>80 & socketAddress~port<>443 then host=host||":"||socketAddress~port
  end
  request="GET "||options~path||" HTTP/1.1"||"0d0a"x
  request=request||"Host: "||host||"0d0a"x
  request=request||"Upgrade: websocket"||"0d0a"x
  request=request||"Connection: Upgrade"||"0d0a"x
  request=request||"Sec-WebSocket-Key: "||key||"0d0a"x
  request=request||"Sec-WebSocket-Version: 13"||"0d0a"x
  if options~origin<>"" then request=request||"Origin: "||options~origin||"0d0a"x
  if options~subprotocols~items>0 then request=request||"Sec-WebSocket-Protocol: "||self~join(options~subprotocols,", ")||"0d0a"x
  supplier=options~extraHeaders~supplier
  do while supplier~available
    request=request||supplier~index||": "||supplier~item||"0d0a"x
    supplier~next
  end
  request=request||"0d0a"x
  if \stream~write(request) then do; stream~close; return .nil; end
  response=self~readHttpHeaders(stream)
  if response=.nil then do; stream~close; return .nil; end
  result=self~validateHandshake(response,key,options)
  if result=.nil then do; stream~close; return .nil; end
  return .WebSocketConnection~new(stream,socketAddress,maskSource,result)

::method readHttpHeaders
  use strict arg stream
  data=""
  marker="0d0a0d0a"x
  do while pos(marker,data)=0
    chunk=stream~read(4096)
    if chunk=.nil | chunk="" then return .nil
    data=data||chunk
    if length(data)>65536 then return .nil
  end
  return left(data,pos(marker,data)+3)

::method validateHandshake
  expose handshakeCrypto
  use strict arg raw,key,options
  lines=raw~makeArray("0d0a"x)
  if lines~items<1 then return .nil
  first=lines[1]
  parts=first~makeArray(" ")
  if parts~items<2 then return .nil
  status=parts[2]+0
  if status<>101 then return .nil
  headers=.directory~new
  do i=2 to lines~items
    line=lines[i]
    if line="" then leave
    p=pos(":",line)
    if p=0 then iterate
    name=lower(strip(left(line,p-1)))
    value=strip(substr(line,p+1))
    headers[name]=value
  end
  if lower(headers["upgrade"])<>"websocket" then return .nil
  if pos("upgrade",lower(headers["connection"]))=0 then return .nil
  expected=handshakeCrypto~expectedAccept(key)
  if expected="" | headers["sec-websocket-accept"]<>expected then return .nil
  selected=""
  if headers["sec-websocket-protocol"]<>.nil then selected=headers["sec-websocket-protocol"]
  if selected<>"" then do
    ok=.false
    do p over options~subprotocols
      if p=selected then ok=.true
    end
    if \ok then return .nil
  end
  return .WebSocketHandshakeResult~new(status,headers,selected,raw)

::method join
  use strict arg items, separator
  out=""
  do i=1 to items~items
    if i>1 then out=out||separator
    out=out||items[i]
  end
  return out

::requires "SocketProvider.cls"
