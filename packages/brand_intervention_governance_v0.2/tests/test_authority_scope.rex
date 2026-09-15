s=.GovernanceFixture~study('SCOPE')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-SCOPE',s,'2026-08-24',2,'CLOCK'); b~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,.GovernanceFixture~rules)~value
a=.BrandInterventionGovernanceAuthority~new('BILLING-BOARD','HUMAN_REVIEW_BOARD','OTHER_INTERVENTION')
d=.BrandInterventionGovernanceDecision~new('D-SCOPE',r,a,'APPROVE_CONTROLLED_PILOT','GOVERNANCE_DECISION:CHANGE-200','2026-08-24T12:00:00Z')
x=d~seal
call assertFalse x~ok,'wrong authority scope rejected'
call assertEqual 'AUTHORITY_SCOPE_MISMATCH',x~code,'scope code'
say 'PASS test_authority_scope'
exit 0
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
