s=.GovernanceFixture~study('REF')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-REF',s,'2026-08-24',2,'CLOCK'); b~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,.GovernanceFixture~rules)~value
a=.BrandInterventionGovernanceAuthority~new('BOARD','HUMAN_REVIEW_BOARD','ALL')
d=.BrandInterventionGovernanceDecision~new('D-REF',r,a,'APPROVE_CONTROLLED_PILOT','Barbie Example at 12 Private Road','2026-08-24T12:00:00Z')
x=d~seal
call assertFalse x~ok,'free prose rejected from decision reference'
call assertEqual 'DECISION_REF_NOT_OPAQUE',x~code,'privacy code'
say 'PASS test_decision_ref_privacy'
exit 0
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
