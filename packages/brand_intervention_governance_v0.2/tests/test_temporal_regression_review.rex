prev=.GovernanceFixture~study('PREV','PROMISING','OBSERVATIONAL','MODEL-6.3',.true,30,80,40,50)
base=.GovernanceFixture~study('BASE','PROMISING','OBSERVATIONAL','MODEL-6.3',.true,35,80,40,50)
/* Current primary remains promising but guardrail is adverse => MIXED. */
curr=.GovernanceFixture~study('CURR','PROMISING','OBSERVATIONAL','MODEL-6.4',.true,30,80,180,80)
t=.GovernanceFixture~temporal(curr,prev,base,'TEMP-REG')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-TEMP',t,'2026-08-24',2,'CLOCK'); b~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,.GovernanceFixture~rules)~value
call assertEqual 'REGRESSION_REVIEW',r~disposition,'current regression kept distinct from baseline'
mat=r~reasoningMaterial
call assertTrue mat~pos('CURRENT_BEGIN')>0,'current evidence present'
call assertTrue mat~pos('PREVIOUS_BEGIN')>0,'previous evidence present'
call assertTrue mat~pos('LONG_BASELINE_BEGIN')>0,'baseline evidence present'
call assertTrue mat~pos('MODEL_VERSION=MODEL-6.4')>0,'current release survives'
call assertTrue mat~pos('MODEL_VERSION=MODEL-6.3')>0,'prior release survives'
call assertTrue r~hasProhibition('AVERAGE_CURRENT_REGRESSION_AWAY_IN_LONG_BASELINE'),'current regression cannot be averaged away'
say 'PASS test_temporal_regression_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
