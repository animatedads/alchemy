call directory value("TEST_ROOT",,"ENVIRONMENT")
trust=value("SMTP_TEST_CA",,"ENVIRONMENT")
signedPath=value("SMTP_TEST_SIGNED",,"ENVIRONMENT")
tamperedPath=value("SMTP_TEST_TAMPERED",,"ENVIRONMENT")
plainPath=value("SMTP_TEST_PLAIN",,"ENVIRONMENT")
if trust="" | signedPath="" then do; say "missing S/MIME fixture env"; exit 2; end
ver=.OpenSslSmimeMessageSignatureVerifier~new(trust,"/tmp","openssl")

signed=readAll(signedPath)
r=ver~inspect(makeRelayMessage(signed),"alice@example.org")
if \r~ok | \r~value~present | \r~value~verified then do; say "FAIL signed verify" r~code r~value~detail; exit 1; end
if \r~value~signerIdentity~caselessEquals("alice@example.org") then do; say "FAIL signer identity" r~value~signerIdentity; exit 1; end
if r~value~certificateId="" then do; say "FAIL certificate id"; exit 1; end

r=ver~inspect(makeRelayMessage(signed),"mallory@example.org")
if \r~value~present | r~value~verified then do; say "FAIL identity mismatch" r~code; exit 1; end

plain=readAll(plainPath)
r=ver~inspect(makeRelayMessage(plain),"")
if r~value~present | r~value~verified then do; say "FAIL unsigned"; exit 1; end

tampered=readAll(tamperedPath)
r=ver~inspect(makeRelayMessage(tampered),"")
if \r~value~present | r~value~verified then do; say "FAIL tampered" r~code; exit 1; end

/* Prove the concrete verifier on the actual SMTP relay critical path. */
d=.FixtureDelivery~new
svc=.SmtpService~new(.nil,.nil,.AllowAuthority~new,.nil,.nil,ver,d)
s=.SmtpSession~new("smime-relay","127.0.0.1","alice@example.org",.true,.true)
r=svc~relayOutbound(s,makeRelayMessage(signed))
if \r~ok then do; say "FAIL concrete signed relay" r~code r~detail; exit 1; end
r=svc~relayOutbound(s,makeRelayMessage(plain))
if r~code<>"RELAY_MESSAGE_SIGNATURE_REQUIRED" then do; say "FAIL concrete unsigned relay" r~code; exit 1; end

/* And prove signed/unsigned inbox routing with that same verifier. */
d=.FixtureDelivery~new
svc=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,ver,d)
inSession=.SmtpSession~new("smime-in","203.0.113.9","",.false,.true)
r=svc~acceptInbound(inSession,makeLocalMessage(signed))
if \r~ok | d~lastMailbox<>"INBOX" then do; say "FAIL concrete signed inbox" r~code d~lastMailbox; exit 1; end
r=svc~acceptInbound(inSession,makeLocalMessage(plain))
if \r~ok | d~lastMailbox<>"INBOX-UNSIGNED" then do; say "FAIL concrete unsigned inbox" r~code d~lastMailbox; exit 1; end

say "OPENSSL S/MIME VERIFIER + SMTP POLICY: OK"
exit 0

readAll: procedure
  use strict arg path
  s=.stream~new(path); s~open("read binary"); data=s~charin(,s~chars); s~close; return data
makeRelayMessage: procedure
  use strict arg content
  e=.SmtpEnvelope~new("alice@example.org"); e~addRecipient("bob@example.net")
  return .SmtpMessage~new(e,content)
makeLocalMessage: procedure
  use strict arg content
  e=.SmtpEnvelope~new("alice@example.org"); e~addRecipient("local@example.org")
  return .SmtpMessage~new(e,content)

::class AllowAuthority subclass SmtpAccessAuthority
::method authorize
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then return .SmtpResult~success("grant","EMAIL_SEND_ALLOWED")
  return .SmtpResult~success("grant","ALLOWED")

::class FixtureDelivery subclass SmtpDeliveryProvider
::attribute lastMailbox
::method init
  expose lastMailbox
  lastMailbox=""
::method classifyRecipients
  use strict arg message
  d=.directory~new; d["local"]=.array~new; d["relay"]=message~envelope~recipients
  if message~envelope~recipients[1]~pos("local@")=1 then do; d["local"]=message~envelope~recipients; d["relay"]=.array~new; end
  return d
::method deliverLocal
  expose lastMailbox
  use strict arg session,message,recipients,mailbox="INBOX"
  lastMailbox=mailbox; return .SmtpResult~success(mailbox,"DELIVERED")
::method relaySigned
  use strict arg session,message,recipients,signatureEvidence
  if \signatureEvidence~validFor(session~principalId) then return .SmtpResult~failure("SIGNATURE_INVALID")
  return .SmtpResult~success("queued","RELAY_QUEUED")
::method quarantine
  use strict arg session,message,reason
  return .SmtpResult~success

::requires "src/SmtpOpenSslSmimeVerifier.cls"
