/* Mixed local+relay recipient transactions must fail before local delivery.
 * This prevents a later relay denial from turning an already-stored local
 * recipient into a retry/duplicate ambiguity.
 */
delivery=.MixedDelivery~new
service=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.UnsignedVerifier~new,delivery)
env=.SmtpEnvelope~new("sender@remote.test")
env~addRecipient("local@example.test")
env~addRecipient("remote@outside.test")
msg=.SmtpMessage~new(env,"test")
session=.SmtpSession~new("mixed","192.0.2.1","",.false,.false)
r=service~acceptInbound(session,msg)
call assert \r~ok,"mixed transaction rejected"
call assert r~code="MIXED_LOCAL_RELAY_TRANSACTION","mixed transaction code"
call assert delivery~localCalls=0,"no local side effect before rejection"
call assert delivery~relayCalls=0,"no relay side effect before rejection"
say "test_mixed_recipient_atomicity: PASS"
exit 0

assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  return

::class UnsignedVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.false,.false,"","","","unsigned"),"UNSIGNED")

::class MixedDelivery subclass SmtpDeliveryProvider
::attribute localCalls get
::attribute relayCalls get
::method init
  expose localCalls relayCalls
  localCalls=0; relayCalls=0
::method classifyRecipients
  use strict arg message
  d=.directory~new
  d["local"]=.array~of(message~envelope~recipients[1])
  d["relay"]=.array~of(message~envelope~recipients[2])
  return d
::method deliverLocal
  expose localCalls
  use strict arg session,message,recipients,mailbox="INBOX"
  localCalls+=1
  return .SmtpResult~success(.true,"DELIVERED")
::method relaySigned
  expose relayCalls
  use strict arg session,message,recipients,signatureEvidence
  relayCalls+=1
  return .SmtpResult~success(.true,"SPOOLED")

::requires "SmtpCore.cls"
