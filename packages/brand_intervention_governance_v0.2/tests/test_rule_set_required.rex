s=.GovernanceFixture~study('RULE-REQ')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-RULE-REQ',s,'2026-08-24',2,'CLOCK'); b~seal
x=.BrandInterventionGovernanceEngine~new~recommend(b)
call assertFalse x~ok,'implicit local default policy is not selected'
call assertEqual 'GOVERNANCE_RULE_SET_REQUIRED',x~code,'explicit rule set required'
say 'PASS test_rule_set_required'
exit 0
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
