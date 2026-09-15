s=.GovernanceFixture~study('RAND','PROMISING','RANDOMIZED')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-RAND',s,'2026-08-24',2,'CLOCK'); b~seal
rules=.BrandInterventionGovernanceRuleSet~new('R',45,25,.false,.true); rules~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertEqual 'ASSOCIATION_ONLY',r~causalStatus,'randomized design does not self-promote causality'
call assertTrue r~externalAuthorityRequired,'randomized still requires external governance authority'
call assertTrue r~reasoningMaterial~pos('RANDOMIZED_DESIGN_PRESENT_BUT_CAUSAL_AUTHORITY_EXTERNAL')>0,'explicit bound'
say 'PASS test_randomized_still_external_authority'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
