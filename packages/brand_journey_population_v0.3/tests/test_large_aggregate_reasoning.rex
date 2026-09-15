p=.BrandJourneyPopulation~new('support-billing-q3')
b=.BrandJourneyPopulationAggregateBucket~new('q3-bucket','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','SUPPORT_TO_BILLING_UNRESOLVED','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',29234,109,500,20,'JOURNEY-CLASSIFIER-V3','JOURNEY-TAXONOMY-0.1','PROCESS-7','MODEL-4',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CASE-17')
b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CASE-22')
call assertTrue b~seal~ok,'aggregate bucket seals'; call assertTrue p~addBucket(b)~ok,'bucket adds'; call assertTrue p~seal~ok,'population seals'
c=.BrandJourneyCohortDefinition~new('q3-current','CURRENT','SUPPORT_TO_BILLING_UNRESOLVED','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JOURNEY-CLASSIFIER-V3','JOURNEY-TAXONOMY-0.1','PROCESS-7','MODEL-4'); call assertTrue c~seal~ok,'cohort seals'
t=.BrandEvidenceThreshold~new('JOURNEY-CONTEXT-LOSS-V1',1000,25,20,5,14,1,1.25,80)
a=.BrandJourneyPopulationAnalyzer~new
r=a~analyze(p,c,t); call assertTrue r~ok,'analysis succeeds'; x=r~value
call assertEqual 29234,x~selection~includedCount,'large denominator retained without 29234 live observations'
call assertEqual 500,x~frame~exposedCount,'feature denominator'
call assertEqual 20,x~frame~exposedOutcomeCount,'joint count'
call assertTrue x~assessment~statisticalSufficient,'threshold met'
call assertEqual 'STRONG',x~assessment~status,'strong supported association'
call assertTrue x~uncertainty~intervalSeparation,'95 percent rate intervals separated'
rr=a~reasoningReport(x); call assertTrue rr~ok,'reasoning report builds'
text=rr~value~reasoningMaterial
call assertTrue text~pos('POPULATION=29234')>0,'population travels to reasoning model'
call assertTrue text~pos('MIN_EXPOSED=25')>0,'threshold travels'
call assertTrue text~pos('FROM=2026-06-01')>0,'time scope travels'
call assertTrue text~pos('PROCESS_VERSION=PROCESS-7')>0,'process cohort travels'
call assertTrue text~pos('MODEL_VERSION=MODEL-4')>0,'model cohort travels'
call assertTrue text~pos('WILSON_95')>0,'uncertainty travels'
call assertTrue text~pos('JOURNEY_FEATURE_CAUSES_OUTCOME')>0,'causal overclaim prohibited'
say 'PASS test_large_aggregate_reasoning'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
