call addpath
crypto=.FixedHandshakeCrypto~new
masker=.FixedMaskSource~new("01020304"x)
stream=.FakeStream~new(.array~of("HTTP/1.1 101 Switching Protocols"||"0d0a"x||,
 "Upgrade: websocket"||"0d0a"x||,
 "Connection: Upgrade"||"0d0a"x||,
 "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="||"0d0a0d0a"x))
address=.SocketAddresses~tcp("127.0.0.1",9001,"ws-test")
access=.WebSocketAccess~new(.NilSocketProvider~new,crypto,masker)
conn=access~connectStream(stream,address,.WebSocketClientOptions~new("/chat","server.example.com"))
call assert conn<>.nil, "handshake accepted"
call assert conn~socketAddress==address, "SocketAddress object preserved"
call assert pos("GET /chat HTTP/1.1",stream~written)>0, "HTTP upgrade request written"
call assert pos("Sec-WebSocket-Version: 13",stream~written)>0, "RFC6455 version header"
call assert conn~sendText("Hello"), "text send"
expected="818501020304"x||"49676f686e"x
call assert right(stream~written,length(expected))=expected, "RFC6455 masked client frame"

serverFrame="8105"x||"World"
stream~appendRead(serverFrame)
msg=conn~receive
call assert msg<>.nil, "server frame decoded"
call assert msg~isText, "text opcode preserved"
call assert msg~payload="World", "payload preserved"
call assert msg~final, "FIN preserved"

long=.WebSocketMessage~new(.WebSocketOpcode~BINARY,copies("A",126))
enc=.WebSocketCodec~encodeClient(long,"11223344"x)
call assert c2x(substr(enc,1,4))="82FE007E", "extended 16-bit payload length"

fragStream=.FakeStream~new(.array~new)
fragHandshake=.WebSocketHandshakeResult~new(101,.directory~new)
frag=.WebSocketConnection~new(fragStream,address,masker,fragHandshake)
fragStream~appendRead("0103"x||"Hel")
fragStream~appendRead("8901"x||"!")
fragStream~appendRead("8002"x||"lo")
assembled=frag~receive
call assert assembled<>.nil, "fragmented message returned"
call assert assembled~isText, "fragmented opcode restored"
call assert assembled~payload="Hello", "fragmented payload reassembled"
call assert assembled~final, "reassembled message final"
call assert pos("8A81"x,fragStream~written)>0, "interleaved ping answered with pong"

closeStream=.FakeStream~new(.array~new)
closeConn=.WebSocketConnection~new(closeStream,address,masker,fragHandshake)
call assert closeConn~close(1000,"bye"), "local close succeeds"
call assert closeConn~state=.WebSocketState~CLOSED, "local close reaches CLOSED"
call assert left(closeStream~written,2)="8885"x, "local close frame transmitted while CLOSING"
call assert \closeStream~isOpen, "local close closes stream"

badStream=.FakeStream~new(.array~of("8001"x||"x"))
badConn=.WebSocketConnection~new(badStream,address,masker,fragHandshake)
bad=badConn~receive
call assert bad=.nil, "unexpected continuation fails closed"
call assert badConn~state=.WebSocketState~CLOSED, "protocol failure closes connection"
call assert \badStream~isOpen, "protocol failure closes stream"

say "PASS websocket RFC6455 access/fragment/close contract"
exit 0

assert: procedure
  use strict arg ok,label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return

addpath: procedure
  return

::class FixedHandshakeCrypto subclass WebSocketHandshakeCrypto
::method clientKey
  return "dGhlIHNhbXBsZSBub25jZQ=="
::method expectedAccept
  use strict arg key
  if key="dGhlIHNhbXBsZSBub25jZQ==" then return "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
  return ""

::class FixedMaskSource subclass WebSocketMaskSource
::method init
  expose mask
  use strict arg mask
  mask=mask
::method nextMask
  expose mask
  return mask

::class FakeStream
::method init
  expose reads written open address
  use strict arg initial=.nil
  if initial=.nil then reads=.array~new
  else reads=initial
  written=""; open=.true
  address=.SocketAddresses~tcp("127.0.0.1",9001,"fake")
::attribute written get
::method appendRead
  expose reads
  use strict arg chunk
  reads~append(chunk)
::method write
  expose written open
  use strict arg bytes
  if \open then return .false
  written=written||bytes
  return .true
::method read
  expose reads open
  use strict arg maximumBytes
  if \open | reads~items=0 then return .nil
  x=reads[1]
  reads~remove(1)
  return x
::method close
  expose open
  open=.false
  return .true
::method socketAddress
  expose address
  return address
::method isOpen
  expose open
  return open

::class NilSocketProvider
::method streamSender
  return .nil
::method streamSenderAt
  return .nil

::requires "WebSocketAccess.cls"
