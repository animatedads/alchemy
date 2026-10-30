/* WebSocketPlatformCrypto.cls
 * ooRexx WebSocket Access v0.1-dev3 optional estate-crypto adapter.
 *
 * This module is intentionally separate from WebSocketAccess.cls:
 * the RFC 6455 access layer remains independent of any concrete crypto package.
 *
 * SHA-1 is required by RFC 6455 Sec-WebSocket-Accept and is supplied by the
 * estate crypto.auth/0.1 companion. Entropy remains an injected authority.
 */

::class WebSocketEntropySource public
::method nextBytes abstract

::class WebSocketBase64 public
::method encode class
  use strict arg bytes
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  out=""
  n=length(bytes)
  i=1
  do while i<=n
    remain=n-i+1
    b1=c2d(substr(bytes,i,1))
    b2=0
    b3=0
    if remain>=2 then b2=c2d(substr(bytes,i+1,1))
    if remain>=3 then b3=c2d(substr(bytes,i+2,1))

    c1=(b1%4)+1
    c2=((b1//4)*16 + b2%16)+1
    c3=((b2//16)*4 + b3%64)+1
    c4=(b3//64)+1

    out=out||substr(alphabet,c1,1)||substr(alphabet,c2,1)
    if remain>=2 then out=out||substr(alphabet,c3,1)
    else out=out||"="
    if remain>=3 then out=out||substr(alphabet,c4,1)
    else out=out||"="
    i+=3
  end
  return out

::class WebSocketCryptoAuthHandshake public subclass WebSocketHandshakeCrypto
::constant MAGIC "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

::method init
  expose entropy
  use strict arg entropy
  if entropy=.nil then raise syntax 88.900 array("WebSocket entropy authority is required")
  entropy=entropy

::method clientKey
  expose entropy
  bytes=entropy~nextBytes(16)
  if bytes=.nil | length(bytes)<>16 then raise syntax 88.900 array("WebSocket entropy authority must return exactly 16 bytes")
  return .WebSocketBase64~encode(bytes)

::method expectedAccept
  use strict arg key
  if key="" then raise syntax 88.900 array("WebSocket client key is required")
  hex=.SHA1~new(key||.WebSocketCryptoAuthHandshake~MAGIC)~digest
  if length(hex)<>40 then raise syntax 88.900 array("crypto.auth SHA-1 returned unexpected digest length")
  return .WebSocketBase64~encode(x2c(hex))

::class WebSocketCryptoAuthMaskSource public subclass WebSocketMaskSource
::method init
  expose entropy
  use strict arg entropy
  if entropy=.nil then raise syntax 88.900 array("WebSocket entropy authority is required")
  entropy=entropy

::method nextMask
  expose entropy
  bytes=entropy~nextBytes(4)
  if bytes=.nil | length(bytes)<>4 then raise syntax 88.900 array("WebSocket entropy authority must return exactly 4 bytes for a frame mask")
  return bytes

::requires "WebSocketAccess.cls"
::requires "CryptoAuth.cls"
