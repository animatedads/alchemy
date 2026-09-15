now = .DateTime~new
catalog = .SecurityPolicyCatalog~new
call assertTrue catalog~isA(.InstitutionalPolicyCatalog),'security catalogue uses shared institutional policy catalogue'
policy = .SecurityTestSupport~basePolicy(now)
call assertEqual .InstitutionalPolicyBuild~EXECUTION_MODEL,policy~executionModel,'security policy explicitly declares fixed institutional execution model'
published = catalog~publish(policy)
call assertTrue published~ok,'security policy publishes through shared catalogue'
call assertTrue published~isA(.SecurityResult),'shared catalogue preserves SecurityResult API contract'
record = catalog~publicationRecord(policy~policyId,policy~version)
call assertTrue record~ok,'shared publication evidence available through security catalogue'
call assertEqual policy~semanticIdentity,record~value~policyIdentity,'publication evidence binds exact security policy'

gate = .InstitutionalPolicyReplayGuard~operative(policy,now)
call assertTrue gate~ok,'security framework satisfies shared replay protocol'
call assertEqual 'OPERATIVE',gate~value~evaluationMode,'operative mode supplied by shared framework'

say 'PASS test_shared_institutional_policy'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'TestSupport.cls'
