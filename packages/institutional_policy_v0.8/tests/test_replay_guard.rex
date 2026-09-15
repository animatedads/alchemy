now = .DateTime~new
future = now + .TimeSpan~new(0,1,0,0,0)
policy = .InstitutionalPolicyRelease~new('P','2.0',future,.nil,'A','B','',.nil,'PAYLOAD')~seal
op = .InstitutionalPolicyReplayGuard~operative(policy,now)
call assertEqual 'POLICY_NOT_EFFECTIVE',op~code,'future policy cannot be operative now'
cf = .InstitutionalPolicyReplayGuard~counterfactual(policy,now)
call assertTrue cf~ok,'future policy may be counterfactual'
call assertEqual 'COUNTERFACTUAL',cf~value~evaluationMode,'counterfactual labelled'
call assertEqual policy~semanticIdentity,cf~value~policyIdentity,'policy identity retained'

same = .InstitutionalPolicyComparison~new(policy,policy,'HOLD','HOLD','TRACE-A','TRACE-B')
call assertTrue same~outcomeChanged = .false,'same outcome not reported changed'
call assertTrue same~traceChanged,'trace change separately reported'

say 'PASS test_replay_guard'
exit 0
assertTrue: procedure
  use arg value,label
  if value = .false then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected <> actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
