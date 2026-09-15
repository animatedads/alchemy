parse arg root qid expectation
h=.QueueStateLockManager~new(root)~acquire(qid,"mixed-rexx-probe",0)
if expectation == "blocked" then do
  if h == .nil then do; say "PASS QueueRexx respects QueueBash state lock"; exit 0; end
  h~release; say "FAIL QueueRexx stole QueueBash state lock"; exit 1
end
if h == .nil then do; say "FAIL QueueRexx could not acquire free lock"; exit 1; end
h~release
say "PASS QueueRexx free lock"
exit 0
::requires "../src/QueueRexxMutation.cls"
