rules=.GovernanceFixture~rules
x=.GovernancePolicyFixture~futureSelectionFailure(rules)
call assertFalse x~ok,'future policy cannot be silently selected early'
call assertEqual 'POLICY_NOT_EFFECTIVE',x~code,'Institutional Policy resolution failure preserved'
say 'PASS test_institutional_policy_not_effective'
exit 0
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'TestGovernancePolicyFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
