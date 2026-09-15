parse arg root
args = .Array~of("/bin/printf", "%s\n", "space value", '$HOME', '`uname`', "it's literal")
req = .QueueSubmitRequest~new("qrx-shell-compat", args, 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp/space dir")
receipt = .QueueSubmitService~new(root, .AllowAllCompatPolicy~new)~submit(req)
if \receipt~ok then do
  say "FAIL submit" receipt~code receipt~detail
  exit 1
end
say receipt~qid
exit 0

::class AllowAllCompatPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxOperations.cls"
