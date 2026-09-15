parse arg root
if root == "" then exit 2
wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 2000000, 3000000, 4)
req = .QueueSubmitRequest~new("wlu-qb-fence", .Array~of("/bin/true"), 25, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp", wlu)
r = .QueueSubmitService~new(root, .AllowPolicy~new)~submit(req)
if \r~ok then do
  say "ERROR" r~code r~detail
  exit 3
end
say r~qid
exit 0
::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::requires "QueueRexxOperations.cls"
