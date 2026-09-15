parse arg root
req = .QueueSubmitRequest~new("qrx-exec-compat", .Array~of("/bin/true"), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")
receipt = .QueueSubmitService~new(root, .AllowAllExecCompatPolicy~new)~submit(req)
if \receipt~ok then do
  say "FAIL submit" receipt~code receipt~detail
  exit 1
end
say receipt~qid
exit 0

::class AllowAllExecCompatPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxOperations.cls"
