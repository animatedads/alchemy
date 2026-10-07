parse arg ready
if ready="" then ready="/tmp/oorexx-smtpd.ready"
svc=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.UnsignedVerifier~new,.FixtureDelivery~new)
server=.SmtpWireServer~new(svc,"127.0.0.1",25252,"fixture",.nil)
server~serve(1,ready)
exit 0
::class FixtureDelivery subclass SmtpDeliveryProvider
::method classifyRecipients
  use strict arg message
  d=.directory~new; d["local"]=message~envelope~recipients; d["relay"]=.array~new; return d
::method deliverLocal
  use strict arg session,message,recipients,mailbox="INBOX"
  return .SmtpResult~success(mailbox,"DELIVERED")
::method quarantine
  use strict arg session,message,reason
  return .SmtpResult~success
::class UnsignedVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.false,.false,"","","","unsigned"),"UNSIGNED")
::requires "src/SmtpWireServer.cls"
