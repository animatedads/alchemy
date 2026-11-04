crypto=.FixedHandshakeCrypto~new
address=.FakeAddress~new("127.0.0.1",8443)

request="GET /wire HTTP/1.1"||"0d0a"x||,
        "Host: rasenfalcon.com"||"0d0a"x||,
        "Upgrade: websocket"||"0d0a"x||,
        "Connection: keep-alive, Upgrade"||"0d0a"x||,
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="||"0d0a"x||,
        "Sec-WebSocket-Version: 13"||"0d0a"x||,
        "Origin: https://rasenfalcon.com"||"0d0a"x||,
        "Sec-WebSocket-Protocol: other, wire.v1"||"0d0a0d0a"x

clientFrame=.WebSocketCodec~encodeClient(.WebSocketMessage~new(.WebSocketOpcode~TEXT,"Hello"),"01020304"x)
stream=.FakeServerStream~new(.array~of(request||clientFrame),address)

origins=.array~of("https://rasenfalcon.com")
protocols=.array~of("wire.v1")
options=.WebSocketServerOptions~new("/wire",origins,protocols)
server=.WebSocketServerAccess~new(crypto)
conn=server~acceptStream(stream,address,options)

call assert conn<>.nil, "server accepts RFC6455 upgrade"
call assert conn~socketAddress==address, "server preserves SocketAddress object"
call assert conn~subprotocol="wire.v1", "server selects supported subprotocol"
call assert pos("HTTP/1.1 101 Switching Protocols",stream~written)>0, "server writes 101"
call assert pos("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",stream~written)>0, "server writes RFC accept"
call assert pos("Sec-WebSocket-Protocol: wire.v1",stream~written)>0, "server writes selected protocol"

msg=conn~receive
call assert msg<>.nil, "coalesced first frame preserved after HTTP headers"
call assert msg~isText, "server receives text frame"
call assert msg~payload="Hello", "server unmasks client payload"

before=length(stream~written)
call assert conn~sendText("World"), "server sends text"
wire=substr(stream~written,before+1)
call assert wire="8105"x||"World", "server frames are unmasked"

/* HTTPS-owned parser handoff: no raw HTTP bytes are re-read. */
headers=.directory~new
headers["host"]="rasenfalcon.com"
headers["upgrade"]="websocket"
headers["connection"]="Upgrade"
headers["sec-websocket-key"]="dGhlIHNhbXBsZSBub25jZQ=="
headers["sec-websocket-version"]="13"
headers["origin"]="https://rasenfalcon.com"
headers["sec-websocket-protocol"]="wire.v1"
upgrade=.WebSocketUpgradeRequest~new("GET","/wire","HTTP/1.1",headers)
handoffFrame=.WebSocketCodec~encodeClient(.WebSocketMessage~new(.WebSocketOpcode~TEXT,"HTTPS-HANDOFF"),"11223344"x)
handoffStream=.FakeServerStream~new(.array~new,address)
handoff=server~acceptParsedRequest(handoffStream,address,upgrade,options,handoffFrame)
call assert handoff<>.nil, "parsed HTTPS upgrade handoff accepted"
handoffMessage=handoff~receive
call assert handoffMessage<>.nil & handoffMessage~payload="HTTPS-HANDOFF", "HTTPS handoff preserves first WebSocket bytes"

badStream=.FakeServerStream~new(.array~of(request||"8101"x||"x"),address)
badConn=server~acceptStream(badStream,address,options)
call assert badConn<>.nil, "bad-frame connection upgrades first"
before=length(badStream~written)
bad=badConn~receive
call assert bad=.nil, "unmasked client frame fails closed"
call assert badConn~state=.WebSocketState~CLOSED, "protocol violation closes server connection"
closeWire=substr(badStream~written,before+1)
call assert left(closeWire,1)="88"x, "server emits unmasked close on protocol failure"

forbidden="GET /wire HTTP/1.1"||"0d0a"x||,
          "Host: rasenfalcon.com"||"0d0a"x||,
          "Upgrade: websocket"||"0d0a"x||,
          "Connection: Upgrade"||"0d0a"x||,
          "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="||"0d0a"x||,
          "Sec-WebSocket-Version: 13"||"0d0a"x||,
          "Origin: https://evil.example"||"0d0a0d0a"x
forbiddenStream=.FakeServerStream~new(.array~of(forbidden),address)
rejected=server~acceptStream(forbiddenStream,address,options)
call assert rejected=.nil, "origin allowlist rejects foreign origin"
call assert pos("HTTP/1.1 403 Forbidden",forbiddenStream~written)>0, "origin rejection is explicit"

oldVersion="GET /wire HTTP/1.1"||"0d0a"x||,
           "Host: rasenfalcon.com"||"0d0a"x||,
           "Upgrade: websocket"||"0d0a"x||,
           "Connection: Upgrade"||"0d0a"x||,
           "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="||"0d0a"x||,
           "Sec-WebSocket-Version: 12"||"0d0a"x||,
           "Origin: https://rasenfalcon.com"||"0d0a0d0a"x
versionStream=.FakeServerStream~new(.array~of(oldVersion),address)
rejected=server~acceptStream(versionStream,address,options)
call assert rejected=.nil, "unsupported WebSocket version rejected"
call assert pos("HTTP/1.1 426 Upgrade Required",versionStream~written)>0, "version rejection uses 426"
call assert pos("Sec-WebSocket-Version: 13",versionStream~written)>0, "version rejection advertises RFC6455 version"

badKey="GET /wire HTTP/1.1"||"0d0a"x||,
       "Host: rasenfalcon.com"||"0d0a"x||,
       "Upgrade: websocket"||"0d0a"x||,
       "Connection: Upgrade"||"0d0a"x||,
       "Sec-WebSocket-Key: short"||"0d0a"x||,
       "Sec-WebSocket-Version: 13"||"0d0a"x||,
       "Origin: https://rasenfalcon.com"||"0d0a0d0a"x
badKeyStream=.FakeServerStream~new(.array~of(badKey),address)
rejected=server~acceptStream(badKeyStream,address,options)
call assert rejected=.nil, "noncanonical client key rejected"
call assert pos("HTTP/1.1 400 Bad Request",badKeyStream~written)>0, "bad key rejection is explicit"

say "PASS websocket server access/HTTPS-upgrade contract"
exit 0

assert: procedure
  use strict arg ok,label
  if ok=.false then do
    say "FAIL" label
    exit 1
  end
  return

::class FixedHandshakeCrypto subclass WebSocketHandshakeCrypto
::method clientKey
  return "not-used-by-server"
::method expectedAccept
  use strict arg key
  if key="dGhlIHNhbXBsZSBub25jZQ==" then return "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
  return ""

::class FakeAddress
::method init
  expose host port
  use strict arg host,port
::attribute host get
::attribute port get

::class FakeServerStream
::method init
  expose reads written open address
  use strict arg reads,address
  written=""
  open=.true
::attribute written get
::method read
  expose reads open
  use strict arg maximumBytes
  if open=.false | reads~items=0 then return .nil
  chunk=reads[1]
  reads~remove(1)
  return chunk
::method write
  expose written open
  use strict arg bytes
  if open=.false then return .false
  written=written||bytes
  return .true
::method close
  expose open
  open=.false
  return .true
::method socketAddress
  expose address
  return address

::requires "WebSocketServerAccess.cls"
