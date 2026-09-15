say .QueueMutationStatus~name(.QueueMutationStatus~OK)
say .QueueTransitionPhase~name(.QueueTransitionPhase~PREPARED)
say .QueuePendingPath~bucketKey(10)
exit 0
::requires "../src/QueueRexxMutation.cls"
