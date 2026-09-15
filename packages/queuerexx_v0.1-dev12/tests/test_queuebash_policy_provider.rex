parse arg root source allowQid authorisedQid blockedQid
if root == "" | source == "" | allowQid == "" | authorisedQid == "" | blockedQid == "" then do
  say "FAIL usage root source allowQid authorisedQid blockedQid"
  exit 2
end

provider = .QueueBashClassPolicyProvider~new(root, source)
if \provider~available then call fail "policy provider not available"

inspection = .QueuePolicyInspectionService~new(root, provider)
allowAssessment = inspection~inspect(allowQid)
if \allowAssessment~allowed then call fail "unblocked job denied " || allowAssessment~code || " " || allowAssessment~detail
if allowAssessment~code \= .QueueBashPolicyCode~ALLOWED then call fail "unexpected allow code " || allowAssessment~code

authAssessment = inspection~inspect(authorisedQid)
if \authAssessment~allowed then call fail "authorised blocked-command job denied " || authAssessment~code || " " || authAssessment~detail

blockAssessment = inspection~inspect(blockedQid)
if blockAssessment~allowed then call fail "blocked job allowed"
if blockAssessment~code \= .QueueBashPolicyCode~DENIED then call fail "unexpected deny code " || blockAssessment~code

gate = .QueueBashExecutionPolicyGate~new(root, provider)
if gate~assessSubmit(.nil)~isAllowed then call fail "submit policy unexpectedly bound"

worker = .QueueWorkerAdmission~new(root, gate)
allowed = worker~claim(allowQid)
if \allowed~ok then call fail "allowed worker claim failed " || allowed~code || " " || allowed~detail
allowRecord = .QueueStateStore~new(root)~findOne(allowQid)
if allowRecord == .nil | allowRecord~state \= .QueueState~RUNNING then call fail "allowed job not running"

authorised = worker~claim(authorisedQid)
if \authorised~ok then call fail "authorised worker claim failed " || authorised~code || " " || authorised~detail
authRecord = .QueueStateStore~new(root)~findOne(authorisedQid)
if authRecord == .nil | authRecord~state \= .QueueState~RUNNING then call fail "authorised job not running"

blocked = worker~claim(blockedQid)
if blocked~status \= .QueueOperationStatus~DENIED then call fail "blocked worker status " || .QueueOperationStatus~name(blocked~status)
if blocked~state \= .QueueState~POL_BLOCKED then call fail "blocked worker state " || .QueueState~name(blocked~state)
blockRecord = .QueueStateStore~new(root)~findOne(blockedQid)
if blockRecord == .nil | blockRecord~state \= .QueueState~POL_BLOCKED then call fail "blocked job not moved to pol_blocked"

say "PASS QueueBash policy provider, command-bound authorisation and QueueRexx worker policy-block transition"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::requires "QueueRexxPolicy.cls"
