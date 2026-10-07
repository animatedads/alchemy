call directory value("TEST_ROOT",,"ENVIRONMENT")
policy=.FakePolicy~new
authority=.FakeAccessControlAuthority~new
adapter=.AccessPermissionsSmtpAuthorityV1~new(authority,policy)
session=.SmtpSession~new("s-access","127.0.0.1","alice@example.org",.true,.true)
e=.SmtpEnvelope~new("alice@example.org"); e~addRecipient("bob@example.net")
m=.SmtpMessage~new(e,"Subject: test"||"0d0a0d0a"x||"body")
m~metadata["signature.verified"]=.true
m~metadata["signature.signerIdentity"]="alice@example.org"
r=adapter~authorize(session,"EMAIL_SEND","SMTP:RELAY",m)
if \r~ok then do; say "FAIL access allow" r~code r~detail; exit 1; end
req=authority~capturedRequest
if req~action<>"EMAIL_SEND" then do; say "FAIL action" req~action; exit 1; end
if req~principalId<>"alice@example.org" then do; say "FAIL principal" req~principalId; exit 1; end
if req~domainId<>"SMTP:MAIL" then do; say "FAIL domain" req~domainId; exit 1; end
if req~attribute("MESSAGE_SIGNATURE_VERIFIED")<>.true then do; say "FAIL signature evidence"; exit 1; end

authority~allowed=.false
r=adapter~authorize(session,"EMAIL_SEND","SMTP:RELAY",m)
if r~ok | r~code<>"SMTP_AUTHORIZATION_DENIED" then do; say "FAIL access deny" r~code; exit 1; end
say "ACCESS PERMISSIONS SMTP ADAPTER: OK"
exit 0

::class FakePolicy public

::class FakeDecision public
::attribute allowed get
::attribute code get
::method init
  expose allowed code
  use strict arg allowedArg,codeArg
  allowed=allowedArg; code=codeArg

::class FakeEnvelope public
::attribute decision get
::method init
  expose decision
  use strict arg decisionArg
  decision=decisionArg

::class FakeAccessResult public
::attribute ok get
::attribute value get
::attribute code get
::method init
  expose ok value code
  use strict arg okArg,valueArg=.nil,codeArg="OK"
  ok=okArg; value=valueArg; code=codeArg

::class FakeAccessControlAuthority public
::attribute allowed
::method capturedRequest
  expose lastRequest
  return lastRequest
::method init
  expose allowed lastRequest
  allowed=.true; lastRequest=.nil
::method decide
  expose allowed lastRequest
  use strict arg request,policy
  lastRequest=request
  if allowed then d=.FakeDecision~new(.true,"ALLOW")
  else d=.FakeDecision~new(.false,"DENY")
  return .FakeAccessResult~new(.true,.FakeEnvelope~new(d),"OK")

::requires "src/SmtpAccessPermissionsAdapter.cls"
