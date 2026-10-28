/* HalfCloseRoundTrip.cls - shared live half-close round trip used by
 * test_real_halfclose_tcp.rex and test_real_halfclose_unix.rex. Requires only
 * SocketProvider.cls, so each runner loads just its own binding.
 *
 * A sends 100 KB, then shutdownSend. B reads until recv returns "", checks
 * all 100 KB arrived, sends 10 KB back, then closes. A reads the 10 KB and
 * then "". Also checks send-after-shutdown and idempotence on a live socket.
 *
 * A failed check first releases the server thread (it may be blocked in
 * accept or recv), then raises a syntax condition. Without that, ooRexx would
 * wait for the blocked thread and the run would hang instead of failing.
 * Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
 */
::class HalfCloseRoundTrip public
::method run class
  use strict arg family, provider
  return self~new(family,provider)~execute

::method init
  expose family provider listener client
  use strict arg family, provider
  listener=.nil; client=.nil

::method execute
  expose family provider listener client
  request=copies("A",102400)
  replyBytes=copies("B",10240)

  listener=provider~listener("loop",4)
  self~check(listener<>.nil,family "listener")
  worker=.HalfCloseServer~new(replyBytes)
  worker~run(listener)
  call SysSleep .2

  client=provider~sender("loop")
  self~check(client<>.nil,family "sender")
  flagged=client~capabilities~halfCloseSend
  if family="UNIX" then self~check(flagged==.true,"UNIX declares halfCloseSend")
  else if \flagged then say "INFO" family "does not declare halfCloseSend yet: end-of-stream checks on recvOpen are skipped"
  self~check(client~sendAll(request)=length(request),"client sent 100 KB")
  self~check(client~shutdownSend==.true,"client shutdownSend")
  self~check(client~shutdownStatus=="SENT","status SENT")
  self~check(client~send("late")=-1,"send after shutdown refused locally")
  self~check(client~shutdownSend==.true,"second shutdownSend is idempotent")
  self~check(client~shutdownStatus=="ALREADY","status ALREADY")

  got=""
  do 2000
    chunk=client~recv(8192)
    if chunk=.nil then leave
    if chunk=="" then leave
    got=got||chunk
  end
  self~check(chunk=="","client saw end of stream as empty string")
  self~check(length(got)=length(replyBytes),"client received the 10 KB reply after its own half-close")
  self~check(got==replyBytes,"reply bytes intact")
  if flagged then do
    self~check(\client~recvOpen,"client recvOpen false after EOF")
    self~check(client~recv(8192)=="","client EOF is sticky")
  end
  ignore=client~close
  client=.nil
  ignore=listener~close
  listener=.nil

  self~check(worker~serverEofSeen,"server saw end of stream as empty string")
  self~check(worker~serverReceived=length(request),"server received all 100 KB before end of stream")
  say "PASS live" family "half-close round trip"
  return 0

::method check
  expose provider listener client
  use strict arg ok, label
  if ok then do
    say "ok" label
    return
  end
  say "FAIL:" label
  /* Release a server thread blocked in accept: connect once, then close. */
  if client=.nil & listener<>.nil then do
    probe=provider~sender("loop")
    if probe<>.nil then ignore=probe~close
  end
  /* Release a server thread blocked in recv: closing ends its stream. */
  if client<>.nil then ignore=client~close
  if listener<>.nil then ignore=listener~close
  raise syntax 88.900 array("FAIL:" label)

::class HalfCloseServer public
::method init
  expose replyBytes serverReceived serverEofSeen
  use strict arg replyBytes
  serverReceived=0; serverEofSeen=.false
::attribute serverReceived get
::attribute serverEofSeen get
::method run
  expose replyBytes serverReceived serverEofSeen
  use strict arg listener
  reply
  peer=listener~accept
  if peer=.nil then return
  do 2000
    chunk=peer~recv(8192)
    if chunk=.nil then leave
    if chunk=="" then do; serverEofSeen=.true; leave; end
    serverReceived+=length(chunk)
  end
  if serverEofSeen then ignore=peer~sendAll(replyBytes)
  ignore=peer~close
  return

::requires "SocketProvider.cls"
