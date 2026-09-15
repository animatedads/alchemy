s=.GovernanceFixture~study('AUTH')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-AUTH',s,'2026-08-24',2,'CLOCK'); b~seal
rules=.GovernanceFixture~rules
ps=.GovernancePolicyFixture~selection(rules,'2.0','SEL-AUTH-DECISION'); call assertTrue ps~ok,'operative policy selection'
r=.BrandInterventionGovernanceEngine~new~recommendUnderInstitutionalPolicy(b,ps~value)~value
call assertEqual 'CONTROLLED_PILOT_REVIEW',r~disposition,'fixture disposition'
a=.BrandInterventionGovernanceAuthority~new('OPS-BOARD','HUMAN_REVIEW_BOARD','SERVICE_RECOVERY_GUIDANCE')
d=.BrandInterventionGovernanceDecision~new('D1',r,a,'APPROVE_CONTROLLED_PILOT','GOVERNANCE_DECISION:CHANGE-123','2026-08-24T12:00:00Z')
zz=d~seal; call assertTrue zz~ok,'aligned decision seals'
call assertTrue d~alignedWithRecommendation,'aligned'
call assertTrue d~externalExecutionRequired,'decision still does not execute'
/* Divergent withdrawal needs opaque justification; prose must fail. */
d2=.BrandInterventionGovernanceDecision~new('D2',r,a,'WITHDRAW','GOVERNANCE_DECISION:CHANGE-124','2026-08-24T12:01:00Z','Barbie Example at 12 Private Road')
call assertFalse d2~seal~ok,'prose cannot hide in override evidence point'
d3=.BrandInterventionGovernanceDecision~new('D3',r,a,'WITHDRAW','GOVERNANCE_DECISION:CHANGE-125','2026-08-24T12:02:00Z','BRAND_INTERVENTION:DECISION:REVIEW-77')
call assertTrue d3~seal~ok,'authorised divergent decision may cite opaque evidence'
call assertFalse d3~alignedWithRecommendation,'divergence recorded'
say 'PASS test_named_authority_and_override_evidence'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'TestGovernancePolicyFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
