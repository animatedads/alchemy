/* Community correspondence approval: pure ooRexx policy, no I/O. */
::class CommunityDraftGate public
::attribute state get
::attribute revision get
::attribute digest get
::attribute account get
::attribute approver get
::attribute operationId get
::method init
  expose state revision digest account approver operationId
  use strict arg accountArg, rev, sha
  account = accountArg~string~strip
  if account == "" then raise syntax 88.900 array("ACCOUNT_REQUIRED")
  if \self~validRevision(rev) | \self~validHash(sha) then raise syntax 88.900 array("VERSION_INVALID")
  revision = rev + 0
  digest = translate(sha)
  state = "DRAFT"
  approver = ""
  operationId = ""
::method validRevision private
  use strict arg rev
  return datatype(rev, "W") & rev > 0
::method validHash private
  use strict arg sha
  h = translate(sha~string~strip)
  return length(h) = 64 & verify(h,"0123456789ABCDEF") = 0
::method matches private
  expose revision digest
  use strict arg rev, sha
  if \self~validRevision(rev) | \self~validHash(sha) then return .false
  return rev = revision & translate(sha) == digest
::method revise
  expose state revision digest approver
  use strict arg rev, sha
  if state == "IN_FLIGHT" | state == "IN_DOUBT" | state == "SENT" then return .false
  if \self~validRevision(rev) | \self~validHash(sha) then return .false
  if rev <= revision then return .false
  revision = rev + 0
  digest = translate(sha)
  state = "DRAFT"
  approver = ""
  return .true
::method approve
  expose account state approver
  use strict arg actor, rev, sha, authority
  if state \== "DRAFT" & state \== "APPROVED" then return .false
  if \self~matches(rev,sha) then return .false
  if \authority~isActive(actor) | \authority~isHuman(actor) then return .false
  if \authority~isAllowed(actor,"MAIL_APPROVE",account) then return .false
  approver = actor
  state = "APPROVED"
  return .true
::method reserveSend
  expose account state approver operationId
  use strict arg sender, rev, sha, op, authority
  if state \== "APPROVED" | op~string~strip == "" then return .false
  if \self~matches(rev,sha) then return .false
  if \authority~isActive(approver) | \authority~isHuman(approver) then return .false
  if \authority~isAllowed(approver,"MAIL_APPROVE",account) then return .false
  if \authority~isActive(sender) | \authority~isAllowed(sender,"MAIL_SEND",account) then return .false
  operationId = op
  state = "IN_FLIGHT"
  return .true
::method markUncertain
  expose state operationId
  use strict arg op
  if state \== "IN_FLIGHT" | op \== operationId then return .false
  state = "IN_DOUBT"
  return .true
::method recordAccepted
  expose state operationId
  use strict arg op, evidence, verifier
  if state \== "IN_FLIGHT" & state \== "IN_DOUBT" then return .false
  if op \== operationId then return .false
  if \verifier~accepted(op,evidence) then return .false
  state = "SENT"
  return .true
::method recordRejected
  expose state operationId
  use strict arg op, verifier
  if state \== "IN_FLIGHT" & state \== "IN_DOUBT" then return .false
  if op \== operationId then return .false
  if \verifier~definitelyNotAccepted(op) then return .false
  state = "APPROVED"
  operationId = ""
  return .true
