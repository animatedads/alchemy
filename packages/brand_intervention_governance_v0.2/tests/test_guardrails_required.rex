s=.GovernanceFixture~study('NOG','PROMISING','OBSERVATIONAL','MODEL-6.4',.false)
call assertEqual 'PROMISING_ASSOCIATION',s~status,'primary alone looks promising'
b=.BrandInterventionGovernanceEvidenceBinding~new('B-NOG',s,'2026-08-24',2,'CLOCK'); b~seal
rules=.BrandInterventionGovernanceRuleSet~new('R',45,25,.false,.true); rules~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertEqual 'REVIEW_REQUIRED',r~disposition,'positive primary without required guardrails cannot progress'
call assertTrue r~hasProhibition('COLLAPSE_GUARDRAILS_INTO_SINGLE_SCORE'),'guardrail discipline explicit'
say 'PASS test_guardrails_required'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
