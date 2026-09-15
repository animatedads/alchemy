/* Primary improves, guardrail gets materially worse. */
s=.GovernanceFixture~study('MIX','PROMISING','OBSERVATIONAL','MODEL-6.4',.true,30,80,180,80)
call assertEqual 'MIXED_EFFECTS',s~status,'fixture is mixed'
b=.BrandInterventionGovernanceEvidenceBinding~new('B-MIX',s,'2026-08-24',2,'CLOCK'); b~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,.GovernanceFixture~rules)~value
call assertEqual 'WITHDRAWAL_REVIEW',r~disposition,'mixed effects cannot become continue/expansion'
call assertTrue r~hasProhibition('OPTIMISE_PRIMARY_OUTCOME_WHILE_IGNORING_GUARDRAIL_HARM'),'guardrail harm explicit'
call assertTrue r~reasoningMaterial~pos('MIXED_EFFECTS')>0,'mixed evidence retained'
say 'PASS test_mixed_guardrail_forces_withdrawal_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
