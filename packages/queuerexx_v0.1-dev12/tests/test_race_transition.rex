parse arg root qid
r=.QueueTransitionService~new(root)~transition(qid,.QueueState~PENDING,.QueueState~RUNNING,.QueueEvent~JOB_CLAIMED,.QueueLockActor~TRANSITION,1)
select
  when r~status == .QueueMutationStatus~OK then say "RACE_REXX=won"
  when r~status == .QueueMutationStatus~SOURCE_NOT_FOUND then say "RACE_REXX=lost-source"
  when r~status == .QueueMutationStatus~LOCK_TIMEOUT then say "RACE_REXX=lost-lock"
  otherwise do; say "FAIL unexpected race status" .QueueMutationStatus~name(r~status) r~detail; exit 1; end
end
exit 0
::requires "../src/QueueRexxMutation.cls"
