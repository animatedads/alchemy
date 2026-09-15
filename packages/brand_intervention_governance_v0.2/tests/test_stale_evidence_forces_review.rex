s=.GovernanceFixture~study('STALE')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-STALE',s,'2026-12-01',100,'CLOCK-AUTH'); b~seal
rules=.BrandInterventionGovernanceRuleSet~new('R',30,25,.false,.true); rules~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertEqual 'REVIEW_REQUIRED',r~disposition,'stale evidence cannot change exposure'
call assertTrue r~hasProhibition('CHANGE_EXPOSURE_FROM_STALE_EVIDENCE'),'stale bound explicit'
call assertTrue r~reasoningMaterial~pos('EVIDENCE_AGE_DAYS=100')>0,'age survives reasoning material'
say 'PASS test_stale_evidence_forces_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
