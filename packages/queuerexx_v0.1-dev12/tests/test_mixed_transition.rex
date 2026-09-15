parse arg root qid
if root == "" | qid == "" then do; say "FAIL args"; exit 2; end
store=.QueueStateStore~new(root)
m=store~findAll(qid)
if m~items \= 1 then do; say "FAIL queuebash pending not visible" m~items; exit 1; end
if m[1]~state \= .QueueState~PENDING then do; say "FAIL expected pending" m[1]~stateName; exit 1; end
r=.QueueTransitionService~new(root)~transition(qid,.QueueState~PENDING,.QueueState~RUNNING,.QueueEvent~JOB_CLAIMED)
if \r~ok then do; say "FAIL transition" .QueueMutationStatus~name(r~status) r~detail; exit 1; end
say "PASS mixed transition" qid
exit 0
::requires "../src/QueueRexxMutation.cls"
