/* A cleanup exception after the definitive final DATA reply must not replace
 * the already-known delivery result with NEXT_HOP_TRANSPORT_EXCEPTION. */
sock=.CleanupFaultSocket~new
connector=.FixtureConnector~new(sock)
transport=.RxSockStartTlsSmtpRelayTransport~new(.nil,connector)
hop=.SmtpNextHop~new("mx.example.test",25,"client.example.test",.false)
env=.SmtpEnvelope~new("<alice@example.test>"); env~addRecipient("<bob@example.test>")
msg=.SmtpMessage~new(env,"From: alice@example.test"||"0d0a0d0a"x||"body"||"0d0a"x)
r=transport~deliver(hop,msg,env~recipients)
call assert r~ok,"delivery survives cleanup exception"
call assert r~code="REMOTE_ATTEMPT","remote attempt result retained"
d=r~value~recipientResults["<bob@example.test>"]
call assert d["state"]=.SmtpSpoolState~DELIVERED,"recipient remains delivered"
call assert d["code"]="250","final DATA code retained"
say "test_post_data_cleanup_exception: PASS"
exit 0

assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  return

::class FixtureConnector public
::method init
  expose socket
  use strict arg socketArg
  socket=socketArg
::method connect
  expose socket
  use strict arg hop
  return .SmtpResult~success(socket,"CONNECTED")

::class CleanupFaultSocket public
::method init
  expose replies index closed
  replies=.array~new
  replies~append("220 mx.example.test ESMTP"||"0d0a"x)
  replies~append("250 mx.example.test"||"0d0a"x)
  replies~append("250 2.1.0 sender ok"||"0d0a"x)
  replies~append("250 2.1.5 recipient ok"||"0d0a"x)
  replies~append("354 continue"||"0d0a"x)
  replies~append("250 2.0.0 queued"||"0d0a"x)
  index=1; closed=.false
::method recv
  expose replies index
  use strict arg size
  if index>replies~items then return ""
  s=replies[index]; index+=1; return s
::method send
  use strict arg data
  if data~upper~left(4)="QUIT" then raise syntax 88.900 array("qualification QUIT cleanup exception")
  return data~length
::method close
  expose closed
  closed=.true
  return .true
::method errno
  return 0

::requires "SmtpOutboundDispatcher.cls"
