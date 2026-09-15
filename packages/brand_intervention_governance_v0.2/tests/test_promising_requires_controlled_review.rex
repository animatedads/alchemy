s=.GovernanceFixture~study('GOOD')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-GOOD',s,'2026-08-24',3,'CLOCK-AUTH'); call assertTrue b~seal~ok,'binding'
rules=.BrandInterventionGovernanceRuleSet~new('RULES',45,25,.true,.true); rules~seal
x=.BrandInterventionGovernanceEngine~new~recommend(b,rules); call assertTrue x~ok,'recommend'; r=x~value
call assertEqual 'CONTROLLED_PILOT_REVIEW',r~disposition,'no temporal expansion without temporal evidence'
call assertTrue r~externalAuthorityRequired,'external authority required'
call assertEqual 'ASSOCIATION_ONLY',r~causalStatus,'association only'
call assertTrue r~hasProhibition('AUTOMATIC_EXECUTION'),'cannot execute itself'
call assertTrue r~hasProhibition('COLLAPSE_GUARDRAILS_INTO_SINGLE_SCORE'),'guardrails cannot collapse to one utility score'
call assertTrue r~hasProhibition('INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT'),'service-as-sales does not confer sales authority'
call assertTrue r~reasoningMaterial~pos('GUARDRAIL_BEGIN')>0,'full guardrail evidence survives'
call assertTrue r~reasoningMaterial~pos('NO_SINGLE_UTILITY_SCORE=1')>0,'reasoning packet explicitly rejects scalar utility'
say 'PASS test_promising_requires_controlled_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
