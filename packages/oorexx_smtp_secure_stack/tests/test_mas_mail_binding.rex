call directory value("TEST_ROOT",,"ENVIRONMENT")

service=.SmtpService~new(.nil,.nil,.MasAllowAuthority~new,.nil,.nil,.MasGoodVerifier~new,.MasDelivery~new)
provider=.SmtpMasMailProvider~new(service)
draft=.MasDraftFixture~new
draft~sender="alice@example.org"
draft~addRecipient("bob@remote.example")
draft~body="From: alice@example.org"||"0d0a"x||"To: bob@remote.example"||"0d0a"x||"Subject: MAS"||"0d0a0d0a"x||"signed fixture"

/* Guest-side booleans are deliberately irrelevant.  submit(draft) lacks a
 * trusted host attribution and must fail closed. */
draft~signaturePresent=.true
draft~signatureVerified=.true
draft~identityMatches=.true
draft~emailSendAuthorized=.true
draft~egressPermitted=.true
if provider~submit(draft)<>"MAS_PRINCIPAL_REQUIRED" then exit 1

r=provider~submitFor("alice@example.org","mas-session-1",draft,.true)
if \r~ok then exit 2
if draft~state<>"RELAY_QUEUED" then exit 3

/* The hard relay rule cannot be disabled through SmtpPolicyConfig. */
cfg=.SmtpPolicyConfig~new
if \cfg~requireVerifiedUserSignatureForRelay then exit 4
signal on syntax name noUnsignedSetter
cfg~requireVerifiedUserSignatureForRelay=.false
exit 5
noUnsignedSetter:
  say "EXPECTED setter rejection rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
  signal off syntax

say "PASS MAS/MAIL secure binding and non-configurable signed relay"
exit 0

::class MasDraftFixture public
::attribute sender
::attribute recipients get
::attribute body
::attribute signaturePresent
::attribute signatureVerified
::attribute identityMatches
::attribute emailSendAuthorized
::attribute egressPermitted
::attribute state
::method init
  expose sender recipients body state
  sender=""; recipients=.array~new; body=""; state="DRAFT"
::method addRecipient
  expose recipients
  use strict arg recipient
  recipients~append(recipient)

::class MasGoodVerifier subclass SmtpMessageSignatureVerifier
::method inspect
  use strict arg message,expectedIdentity=""
  e=.SmtpMessageSignatureEvidence~new(.true,.true,"alice@example.org","cert-alice","fixture","verified")
  return .SmtpResult~success(e,"SIGNED_VERIFIED")

::class MasAllowAuthority subclass SmtpAccessAuthority
::method authorize
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then return .SmtpResult~success("grant","EMAIL_SEND_ALLOWED")
  return .SmtpResult~success("grant","ALLOWED")

::class MasDelivery subclass SmtpDeliveryProvider
::method relaySigned
  use strict arg session,message,recipients,signatureEvidence
  if \signatureEvidence~validFor(session~principalId) then return .SmtpResult~failure("SIGNATURE_INVALID")
  return .SmtpResult~success("queued","RELAY_QUEUED")

::requires "src/SmtpCore.cls"
::requires "src/SmtpMasMailBinding.cls"
