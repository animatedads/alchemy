call directory value("TEST_ROOT",,"ENVIRONMENT")
say "SMTP policy tests"
pass=0; fail=0
call check "no message signature => no relay", testUnsignedRelay()
call check "signature but EMAIL_SEND denied => no relay", testSignedUnauthorizedRelay()
call check "signed + EMAIL_SEND authorized => relay", testSignedAuthorizedRelay()
call check "inbound verified signature => INBOX", testInboundSigned()
call check "inbound unsigned => INBOX-UNSIGNED", testInboundUnsigned()
call check "inbound invalid signature => INBOX-UNSIGNED", testInboundInvalid()
call check "required model unavailable fails closed", testModelRequired()
call check "ingress inspector sees signature evidence", testInspectorSeesSignature()
call check "egress event carries signature/policy provenance", testEventProjection()
if fail>0 then exit 1
say "PASS" pass "tests"
exit 0

check: procedure expose pass fail
  parse arg name,ok
  if ok then do; pass+=1; say "PASS" name; end
  else do; fail+=1; say "FAIL" name; end
  return

testUnsignedRelay: procedure
  svc=.SmtpService~new(.nil,.nil,.AllowAuthority~new,.nil,.nil,.UnsignedVerifier~new,.GoodDelivery~new)
  s=.SmtpSession~new("s1","127.0.0.1","alice@example.org",.true,.true)
  r=svc~relayOutbound(s,makeMessage())
  return r~code="RELAY_MESSAGE_SIGNATURE_REQUIRED"

testSignedUnauthorizedRelay: procedure
  svc=.SmtpService~new(.nil,.nil,.DenyAuthority~new,.nil,.nil,.GoodVerifier~new,.GoodDelivery~new)
  s=.SmtpSession~new("s2","127.0.0.1","alice@example.org",.true,.true)
  r=svc~relayOutbound(s,makeMessage())
  return r~code="EMAIL_SEND_NOT_AUTHORIZED"

testSignedAuthorizedRelay: procedure
  svc=.SmtpService~new(.nil,.nil,.AllowAuthority~new,.nil,.nil,.GoodVerifier~new,.GoodDelivery~new)
  s=.SmtpSession~new("s3","127.0.0.1","alice@example.org",.true,.true)
  r=svc~relayOutbound(s,makeMessage())
  return r~ok

testInboundSigned: procedure
  d=.GoodDelivery~new
  svc=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.GoodVerifier~new,d)
  s=.SmtpSession~new("s4","203.0.113.44","",.false,.true)
  r=svc~acceptInbound(s,makeLocalMessage())
  return r~ok & r~value="INBOX" & d~lastMailbox="INBOX"

testInboundUnsigned: procedure
  d=.GoodDelivery~new
  svc=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.UnsignedVerifier~new,d)
  s=.SmtpSession~new("s5","203.0.113.44","",.false,.true)
  r=svc~acceptInbound(s,makeLocalMessage())
  return r~ok & r~value="INBOX-UNSIGNED" & d~lastMailbox="INBOX-UNSIGNED"

testInboundInvalid: procedure
  d=.GoodDelivery~new
  svc=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.InvalidVerifier~new,d)
  s=.SmtpSession~new("s6","203.0.113.44","",.false,.true)
  r=svc~acceptInbound(s,makeLocalMessage())
  return r~ok & r~value="INBOX-UNSIGNED" & d~lastMailbox="INBOX-UNSIGNED"

testModelRequired: procedure
  c=.SmtpPolicyConfig~new; c~modelRequiredIngress=.true
  svc=.SmtpService~new(c,.nil,.nil,.nil,.nil,.UnsignedVerifier~new,.GoodDelivery~new)
  s=.SmtpSession~new("s7")
  r=svc~acceptInbound(s,makeLocalMessage())
  return r~code="MODEL_REQUIRED_UNAVAILABLE"

testInspectorSeesSignature: procedure
  i=.SignatureMetadataInspector~new
  svc=.SmtpService~new(.nil,.nil,.nil,i,.nil,.GoodVerifier~new,.GoodDelivery~new)
  s=.SmtpSession~new("s8","203.0.113.44","",.false,.true)
  r=svc~acceptInbound(s,makeLocalMessage())
  return r~ok & i~sawVerified

testEventProjection: procedure
  ev=.CaptureEventSink~new
  i=.SignatureMetadataInspector~new
  svc=.SmtpService~new(.nil,.nil,.AllowAuthority~new,i,.nil,.GoodVerifier~new,.GoodDelivery~new,ev)
  s=.SmtpSession~new("s9","127.0.0.1","alice@example.org",.true,.true)
  r=svc~relayOutbound(s,makeMessage())
  if \r~ok then return .false
  e=ev~lastEvent
  if e==.nil then return .false
  if e["kind"]<>"egress.spooled" then return .false
  if e["signature.verified"]<>.true then return .false
  if e["signature.signerIdentity"]<>"alice@example.org" then return .false
  if e["policy.egress.action"]<>"allow" then return .false
  return .true

makeMessage: procedure
  e=.SmtpEnvelope~new("alice@example.org"); e~addRecipient("bob@remote.example")
  return .SmtpMessage~new(e,"Subject: test"||"0d0a0d0a"x||"hello")
makeLocalMessage: procedure
  e=.SmtpEnvelope~new("outside@example.net"); e~addRecipient("local@example.org")
  return .SmtpMessage~new(e,"Subject: hello"||"0d0a0d0a"x||"hello")

::class CaptureEventSink subclass SmtpEventSink
::attribute lastEvent get
::method init
  expose lastEvent
  lastEvent=.nil
::method emit
  expose lastEvent
  use strict arg event
  lastEvent=event; return .true

::class SignatureMetadataInspector subclass SmtpPolicyInspector
::attribute sawVerified get
::method init
  expose sawVerified
  sawVerified=.false
::method inspect
  expose sawVerified
  use strict arg direction,session,message,context=.nil
  if message~metadata~hasIndex("signature.verified") then sawVerified=message~metadata["signature.verified"]
  return .SmtpInspection~new(direction,"allow")

::class AllowAuthority subclass SmtpAccessAuthority
::method authorize
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then return .SmtpResult~success("grant","EMAIL_SEND_ALLOWED")
  return .SmtpResult~success("grant","ALLOWED")

::class DenyAuthority subclass SmtpAccessAuthority
::method authorize
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then return .SmtpResult~failure("EMAIL_SEND_DENIED")
  return .SmtpResult~success("grant","ALLOWED")

::class GoodVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  signer="alice@example.org"
  e=.SmtpMessageSignatureEvidence~new(.true,.true,signer,"cert-alice","fixture","verified")
  return .SmtpResult~success(e,"SIGNED_VERIFIED")

::class UnsignedVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.false,.false,"","","","unsigned"),"UNSIGNED")

::class InvalidVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.false,"alice@example.org","cert-alice","fixture","bad signature"),"SIGNATURE_INVALID")

::class GoodDelivery subclass SmtpDeliveryProvider
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
  lastMailbox=mailbox
  return .SmtpResult~success(mailbox,"DELIVERED")
::method relaySigned
  use strict arg session,message,recipients,signatureEvidence
  if \signatureEvidence~validFor(session~principalId) then return .SmtpResult~failure("SIGNATURE_INVALID")
  return .SmtpResult~success("queued","RELAY_QUEUED")
::method quarantine
  use strict arg session,message,reason
  return .SmtpResult~success

::requires "src/SmtpCore.cls"
