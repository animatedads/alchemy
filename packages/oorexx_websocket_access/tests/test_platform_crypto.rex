/* WebSocket estate crypto adapter contract.
 * Deterministic entropy is used only to prove the adapter contract and RFC vector.
 */
entropy=.DeterministicEntropy~new("the sample nonce"||"01020304"x)
handshake=.WebSocketCryptoAuthHandshake~new(entropy)
key=handshake~clientKey
call assert key="dGhlIHNhbXBsZSBub25jZQ==", "RFC6455 client key vector"
accept=handshake~expectedAccept(key)
call assert accept="s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "RFC6455 accept vector"

masker=.WebSocketCryptoAuthMaskSource~new(entropy)
mask=masker~nextMask
call assert c2x(mask)="01020304", "mask bytes supplied by injected entropy authority"

call assert .WebSocketBase64~encode("")="", "base64 empty"
call assert .WebSocketBase64~encode("f")="Zg==", "base64 one byte"
call assert .WebSocketBase64~encode("fo")="Zm8=", "base64 two bytes"
call assert .WebSocketBase64~encode("foo")="Zm9v", "base64 three bytes"
call assert .WebSocketBase64~encode("foobar")="Zm9vYmFy", "base64 multi-block"

say "PASS websocket estate crypto adapter contract"
exit 0

assert: procedure
  use strict arg ok,label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return

::class DeterministicEntropy public subclass WebSocketEntropySource
::method init
  expose bytes offset
  use strict arg bytes
  offset=1

::method nextBytes
  expose bytes offset
  use strict arg count
  count=count+0
  if count<1 then raise syntax 88.900 array("positive entropy byte count required")
  if offset+count-1>length(bytes) then raise syntax 88.900 array("deterministic entropy exhausted")
  out=substr(bytes,offset,count)
  offset+=count
  return out

::requires "WebSocketPlatformCrypto.cls"
