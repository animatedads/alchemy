/* Pure policy regression, not mail service acceptance. */
hashA = copies("A",64)
hashB = copies("B",64)
authority = .FakeAuthority~new
verifier = .FakeVerifier~new
gate = .CommunityDraftGate~new("chatgpt@rasenfalcon.com",1,hashA)
call check \gate~reserveSend("sender",1,hashA,"op",authority),"unapproved blocked"
call check \gate~approve("agent",1,hashA,authority),"AI not approver"
call check \gate~approve("reviewer",1,hashB,authority),"wrong digest"
call check gate~approve("reviewer",1,hashA,authority),"human approved"
authority~revoke
call check \gate~reserveSend("sender",1,hashA,"op",authority),"revoked reviewer"
authority~restore
call check gate~revise(2,hashB),"edit invalidation"
call check \gate~reserveSend("sender",2,hashB,"op",authority),"no silent reapproval"
call check \gate~approve("reviewer",1,hashA,authority),"stale approval"
call check gate~approve("reviewer",2,hashB,authority),"new approval"
call check \gate~reserveSend("intruder",2,hashB,"op",authority),"send scope"
call check gate~reserveSend("sender",2,hashB,"op",authority),"send reservation"
call check \gate~revise(3,hashA),"inflight mutation"
call check \gate~recordAccepted("op","proof",verifier),"fake SMTP receipt"
call check gate~markUncertain("op"),"ambiguous SMTP status"
call check \gate~reserveSend("sender",2,hashB,"again",authority),"no blind resend"
verifier~admit
call check gate~recordAccepted("op","proof",verifier),"verified receipt"
call check gate~state == "SENT","terminal SENT"
say "PASS: 17 decision checks"
exit 0
check: procedure
  use strict arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return
::class FakeAuthority
::attribute revoked
::method init
  expose revoked
  revoked = .false
::method revoke
  expose revoked
  revoked = .true
::method restore
  expose revoked
  revoked = .false
::method isActive
  expose revoked
  use strict arg who
  if who == "reviewer" then return \revoked
  return who == "sender" | who == "agent"
::method isHuman
  use strict arg who
  return who == "reviewer"
::method isAllowed
  use strict arg who, action, account
  if account \== "chatgpt@rasenfalcon.com" then return .false
  if action == "MAIL_APPROVE" then return who == "reviewer"
  if action == "MAIL_SEND" then return who == "sender"
  return .false
::class FakeVerifier
::attribute valid
::method init
  expose valid
  valid = .false
::method admit
  expose valid
  valid = .true
::method accepted
  expose valid
  use strict arg op, receipt
  return valid & op == "op" & receipt == "proof"
::method definitelyNotAccepted
  use strict arg op
  return .false
::requires "CommunityDraftGate.cls"
