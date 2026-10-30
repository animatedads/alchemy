/* Regression: once a final DATA reply has been received, cleanup exceptions
 * from QUIT or close must not turn a definitive remote result into a retryable
 * transport failure.
 */
recipient="bob@example.org"
recipients=.Array~of(recipient)
env=.SmtpEnvelope~new("<alice@example.org>")
env~addRecipient("<"||recipient||">")
message=.SmtpMessage~new(env,"Subject: cleanup regression"||"0d0a0d0a"x||"body"||"0d0a"x)
hop=.SmtpNextHop~new("mx.example.org",25,"smtp.test",.false)

do mode over .Array~of("QUIT","CLOSE")
  endpoint=.ThrowingCleanupSocket~new(mode)
  connector=.FixtureConnector~new(endpoint)
  transport=.RxSockStartTlsSmtpRelayTransport~new(.nil,connector)
  r=transport~deliver(hop,message,recipients)
  call assertTrue r~ok,mode||" cleanup exception preserves remote attempt"
  call assertEq r~code,"REMOTE_ATTEMPT",mode||" result code"
  d=r~value~recipientResults[recipient]
  call assertTrue d<>.nil,mode||" recipient result present"
  call assertEq d["state"],.SmtpSpoolState~DELIVERED,mode||" recipient delivered"
  call assertEq d["code"],"250",mode||" final reply retained"
end

say "review_cleanup_exception: PASS"
exit 0

assertTrue: procedure
  use arg truth,label
  if truth then return
  say "FAIL" label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::class FixtureConnector public
::method init
  expose endpoint
  use strict arg endpointArg
  endpoint=endpointArg
::method connect
  expose endpoint
  use strict arg hop
  return .SmtpResult~success(endpoint,"CONNECTED")

::class ThrowingCleanupSocket public
::method init
  expose mode transcript returned
  use strict arg modeArg
  mode=modeArg
  returned=.false
  transcript="220 mx.example.org ESMTP0d0a"x || -
             "250 mx.example.org0d0a"x || -
             "250 2.1.0 sender ok0d0a"x || -
             "250 2.1.5 recipient ok0d0a"x || -
             "354 continue0d0a"x || -
             "250 2.0.0 accepted0d0a"x
::method recv
  expose transcript returned
  use strict arg maxBytes
  if returned then return ""
  returned=.true
  return transcript
::method send
  expose mode
  use strict arg data
  if mode="QUIT" then if data~upper~left(4)="QUIT" then raise syntax 93.900 additional("synthetic QUIT cleanup failure")
  return data~length
::method close
  expose mode
  if mode="CLOSE" then raise syntax 93.900 additional("synthetic close cleanup failure")
  return 0

::requires "src/SmtpOutboundDispatcher.cls"
