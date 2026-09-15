parse arg root expectedQid
worker = .QueueWorkerAdmission~new(root, .AllowClaimCompatPolicy~new)
receipt = worker~claimNext
if \receipt~ok then do
  say "FAIL claim" receipt~code receipt~detail
  exit 1
end
if receipt~qid \= expectedQid then do
  say "FAIL wrong qid" receipt~qid expectedQid
  exit 1
end
if receipt~state \= .QueueState~RUNNING then do
  say "FAIL wrong state" .QueueState~name(receipt~state)
  exit 1
end
say "PASS QueueRexx typed worker admission claims QueueBash record through transition kernel"
exit 0

::class AllowClaimCompatPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxOperations.cls"
