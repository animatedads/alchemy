/* test_halfclose_contract.rex - socket.halfclose/0.1 common contract.
 * Deterministic: fake transports only, no network, no root.
 * Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
 */
call main
exit 0

main:
  call assert .SocketProviderBuild~HALF_CLOSE_API="socket.halfclose/0.1","half-close API constant"

  /* Capabilities: a seven-argument call keeps its meaning, flag is false. */
  old=.SocketCapabilities~new("tcp","INET",.true,.true,.true,.false,.false)
  call assert old~halfCloseSend==.false,"seven-argument capabilities default halfCloseSend to false"
  call assert old~multicast==.false,"seven-argument multicast unchanged"
  call assert .SocketFamilies~tcp~capabilities~halfCloseSend==.false,"TCP family waits for test 0 before declaring halfCloseSend"
  call assert .SocketFamilies~unix~capabilities~halfCloseSend==.true,"UNIX family declares halfCloseSend"
  call assert .SocketFamilies~tls~capabilities~halfCloseSend==.false,"TLS family does not declare halfCloseSend"
  call assert .SocketFamilies~xtp~capabilities~halfCloseSend==.false,"XTP family does not declare halfCloseSend"
  call assert .SocketFamilies~udp~capabilities~halfCloseSend==.false,"UDP family does not declare halfCloseSend"
  call assert .SocketFamilies~norm~capabilities~halfCloseSend==.false,"NORM family does not declare halfCloseSend"

  /* A UNIX address: its family declares halfCloseSend, so the end-of-stream
   * rules apply. No socket is opened; the transports are fakes. */
  streamAddress=.SocketAddresses~unix("/tmp/oorexx-halfclose-contract.sock","halfclose")
  tcpAddress=.SocketAddresses~tcp("192.0.2.10",9000,"halfclose")

  /* 1. Supported through a binding-supplied half-closer. */
  raw=.FakeStream~new
  closer=.FakeHalfCloser~new(.true)
  c=.ProviderSocketConnection~new(raw,streamAddress,closer)
  call assert c~sendOpen,"sendOpen starts true"
  call assert c~recvOpen,"recvOpen starts true"
  call assert c~shutdownStatus=="","shutdownStatus starts empty"
  call assert c~send("abc")=3,"send before shutdown reaches transport"
  call assert c~shutdownSend==.true,"shutdownSend returns true when the closer succeeds"
  call assert c~shutdownStatus=="SENT","status SENT"
  call assert \c~sendOpen,"sendOpen false after shutdown"
  call assert closer~calls=1,"closer called once"
  call assert closer~lastSocket==raw,"closer receives the unwrapped native socket"
  call assert raw~closed==.false,"shutdownSend never closes the transport"

  /* 2. Send after shutdown fails locally and reaches nothing. */
  before=raw~sent
  call assert c~send("late")=-1,"send after shutdown returns -1"
  call assert c~sendAll("late")=-1,"sendAll after shutdown returns -1"
  call assert raw~sent==before,"no bytes reach the transport after shutdown"

  /* 3. Idempotence. */
  call assert c~shutdownSend==.true,"second shutdownSend returns true"
  call assert c~shutdownStatus=="ALREADY","status ALREADY"
  call assert closer~calls=1,"closer not called again"

  /* recv still works after shutdownSend; EOF is "" and sticky (test 6). */
  raw~queue("reply")
  call assert c~recv(64)=="reply","recv still works after shutdownSend"
  call assert c~recvOpen,"recvOpen still true before EOF"
  call assert c~recv(64)=="","EOF read as empty string"
  call assert \c~recvOpen,"recvOpen false after EOF"
  reads=raw~reads
  call assert c~recv(64)=="","EOF sticky 1"
  call assert c~recv(64)=="","EOF sticky 2"
  call assert c~recv(64)=="","EOF sticky 3"
  call assert raw~reads=reads,"sticky EOF does not touch the transport"
  call assert c~close=0,"full close still closes the transport"
  call assert raw~closed,"transport closed by close"
  call assert c~closed,"connection records close"
  call assert c~recv(64)==.nil,"recv after close returns .nil"
  call assert c~shutdownSend==.false,"shutdownSend after close returns false"
  call assert c~shutdownStatus=="CLOSED","status CLOSED"
  call assert closer~calls=1,"a closed descriptor is never touched again"

  /* close without any earlier shutdown: shutdownSend must not reach the closer */
  closer6=.FakeHalfCloser~new(.true)
  c6=.ProviderSocketConnection~new(.FakeStream~new,streamAddress,closer6)
  ignore=c6~close
  call assert c6~shutdownSend==.false,"shutdownSend after plain close returns false"
  call assert closer6~calls=0,"closer not called after close"

  /* TCP: the half-closer still works, but the family does not promise
   * end-of-stream semantics until test 0 passes. */
  tcpRaw=.FakeStream~new
  c7=.ProviderSocketConnection~new(tcpRaw,tcpAddress,.FakeHalfCloser~new(.true))
  call assert c7~shutdownSend==.true,"TCP half-closer used even before the family flag is set"
  call assert c7~recv(64)=="","TCP fake returns empty"
  call assert c7~recvOpen,"recvOpen unchanged while TCP does not declare halfCloseSend"

  /* Native socket that implements SHUTDOWNSEND itself is preferred. */
  nativeHalf=.FakeNativeHalfStream~new
  c2=.ProviderSocketConnection~new(nativeHalf,streamAddress,.FakeHalfCloser~new(.false))
  call assert c2~shutdownSend==.true,"native SHUTDOWNSEND used"
  call assert nativeHalf~halfClosed,"native half-close performed"

  /* 4. Fail closed: no closer, no native method. */
  plain=.FakeStream~new
  c3=.ProviderSocketConnection~new(plain,streamAddress)
  call assert c3~shutdownSend==.false,"unsupported shutdownSend returns false"
  call assert c3~shutdownStatus=="NOT_SUPPORTED","status NOT_SUPPORTED"
  call assert c3~sendOpen,"unsupported shutdown leaves send open"
  call assert c3~send("still")=5,"connection still sends after NOT_SUPPORTED"
  call assert plain~closed==.false,"NOT_SUPPORTED never closes"

  /* Closer that fails: FAILED, still fully open. */
  c4=.ProviderSocketConnection~new(.FakeStream~new,streamAddress,.FakeHalfCloser~new(.false))
  call assert c4~shutdownSend==.false,"failed shutdownSend returns false"
  call assert c4~shutdownStatus=="FAILED","status FAILED"
  call assert c4~sendOpen,"failed shutdown leaves send open"

  /* Family without halfCloseSend keeps historical recv: "" does not end it. */
  xtpRaw=.FakeStream~new
  c5=.ProviderSocketConnection~new(xtpRaw,.SocketAddresses~xtp("PEER"))
  call assert c5~recv(64)=="","XTP fake returns empty"
  call assert c5~recvOpen,"recvOpen unchanged for a family without halfCloseSend"

  /* Stream view. */
  sraw=.FakeStream~new
  s=.ProviderSocketConnection~new(sraw,streamAddress,.FakeHalfCloser~new(.true))~asStream
  call assert s~write("x"),"stream write before closeWrite"
  call assert s~closeWrite==.true,"closeWrite delegates to shutdownSend"
  call assert s~write("y")==.false,"stream write after closeWrite fails"
  call assert s~read(8)=="","stream read passes EOF through"
  call assert s~shutdownWrite==.true,"shutdownWrite alias (DebugSocketTransport) reports ALREADY as true"
  call assert s~endpoint~shutdownStatus=="ALREADY","alias reaches the same connection"
  ignore=s~close
  call assert s~closeWrite==.false,"closeWrite on a closed stream returns false"
  unsupported=.ProviderSocketConnection~new(.FakeStream~new,streamAddress)~asStream
  call assert unsupported~closeWrite==.false,"closeWrite returns false when unsupported"

  /* Accepted connections inherit the listener's half-closer. */
  listenerAddress=.SocketAddresses~tcp("192.0.2.1",9000,"LISTENER")
  peer=.FakeStream~new
  lcloser=.FakeHalfCloser~new(.true)
  listener=.ProviderSocketListener~new(.FakeListener~new(peer),listenerAddress,lcloser)
  accepted=listener~accept
  call assert accepted<>.nil,"accept returned a connection"
  call assert accepted~shutdownSend==.true,"accepted connection half-closes"
  call assert lcloser~calls=1,"listener half-closer used for accepted peer"
  accepted2=listener~tryAccept
  call assert accepted2~shutdownSend==.true,"tryAccept connection half-closes"

  /* dev14 defect fixed here: a peer without ADDRESS falls back to the
   * listener address object, not to an unset variable. */
  call assert accepted~address==listenerAddress,"accept fallback is the listener address object"
  call assert accepted2~address==listenerAddress,"tryAccept fallback is the listener address object"

  say "PASS socket.halfclose/0.1 contract"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeStream public
::method init
  expose sent closed inbox reads
  sent=""; closed=.false; inbox=.queue~new; reads=0
::attribute sent get
::attribute closed get
::attribute reads get
::method queue
  expose inbox
  use strict arg bytes
  inbox~queue(bytes)
::method send
  expose sent
  use strict arg bytes
  sent=sent||bytes
  return length(bytes)
::method recv
  expose inbox reads
  use strict arg maximumBytes
  reads+=1
  if inbox~items=0 then return ""
  return inbox~pull
::method close
  expose closed
  closed=.true
  return 0

::class FakeNativeHalfStream public subclass FakeStream
::method init
  expose halfClosed
  halfClosed=.false
  self~init:super
::attribute halfClosed get
::method shutdownSend
  expose halfClosed
  halfClosed=.true
  return .true

::class FakeHalfCloser public
::method init
  expose result calls lastSocket
  use strict arg result
  calls=0; lastSocket=.nil
::attribute calls get
::attribute lastSocket get
::method shutdownSend
  expose result calls lastSocket
  use strict arg socket
  calls+=1; lastSocket=socket
  return result

::class FakeListener public
::method init
  expose peer
  use strict arg peer
::method accept
  expose peer
  return peer
::method tryAccept
  expose peer
  return peer
::method close
  return 0

::requires "SocketProvider.cls"
