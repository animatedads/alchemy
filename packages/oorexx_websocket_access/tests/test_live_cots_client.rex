/* Live COTS wire qualification. The fixed key is the RFC 6455 example nonce;
 * this probe validates interoperability/framing only. Production randomness
 * remains the injected WebSocketHandshakeCrypto authority's responsibility. */
addrp=.RegisteredSocketAddressProvider~new
addr=.SocketAddresses~tcp("127.0.0.1",18765,"ws-live")
addrp~register("ws-live",addr,"SENDER")
sp=.SocketProvider~new(addrp)
sp~registerBinding(.SocketTransportKind~TCP,.RxSockTcpBinding~new)
access=.WebSocketAccess~new(sp,.FixedHandshakeCrypto~new,.CyclingMaskSource~new)
conn=access~connect("ws-live",.WebSocketClientOptions~new("/","127.0.0.1:18765"))
if conn=.nil then do; say "FAIL live COTS handshake"; exit 1; end
if \conn~sendText("spiral1-websocket") then do; say "FAIL live COTS send"; exit 2; end
msg=conn~receive
if msg=.nil then do; say "FAIL live COTS receive"; exit 3; end
if \msg~isText | msg~payload<>"spiral1-websocket" then do; say "FAIL live COTS echo"; exit 4; end
conn~close
say "PASS live RFC6455 COTS echo via SocketProvider isolation"
exit 0

::class FixedHandshakeCrypto subclass WebSocketHandshakeCrypto
::method clientKey
  return "dGhlIHNhbXBsZSBub25jZQ=="
::method expectedAccept
  use strict arg key
  if key="dGhlIHNhbXBsZSBub25jZQ==" then return "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
  return ""

::class CyclingMaskSource subclass WebSocketMaskSource
::method init
  expose counter
  counter=1
::method nextMask
  expose counter
  a=counter//251+1; b=(counter+17)//251+1; c=(counter+61)//251+1; d=(counter+103)//251+1
  counter+=1
  return .WebSocketCodec~byte(a)||.WebSocketCodec~byte(b)||.WebSocketCodec~byte(c)||.WebSocketCodec~byte(d)

::requires "WebSocketAccess.cls"
::requires "RxSockSocketBinding.cls"
