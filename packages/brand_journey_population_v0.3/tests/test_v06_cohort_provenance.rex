/* Brand Journey Population v0.2 must satisfy Brand Interaction Effect v0.6
   cohort-quality gates with explicit selection provenance, not only counts. */
p=.BrandJourneyPopulation~new('prov-pop')
good=.BrandJourneyPopulationAggregateBucket~new('good','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',1000,80,200,50,'JV6','JT6','PROC-9','MODEL-7',86400)
good~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:SUPPORT-1')
good~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:COUNTER-1')
call assertTrue good~seal~ok,'good bucket seals'; call assertTrue p~addBucket(good)~ok,'good bucket adds'
wrong=.BrandJourneyPopulationAggregateBucket~new('wrong-model','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',100,10,20,5,'JV6','JT6','PROC-9','MODEL-OLD',86400)
call assertTrue wrong~seal~ok,'wrong bucket seals'; call assertTrue p~addBucket(wrong)~ok,'wrong bucket adds'; call assertTrue p~seal~ok,'population seals'

c=.BrandJourneyCohortDefinition~new('prov-current','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z',20,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV6','JT6','PROC-9','MODEL-7')
call assertTrue c~configureProvenance('BRAND_JOURNEY_POPULATION','SUPPORT_JOURNEY_STORE','BRAND_JOURNEY','SUPPORT_BILLING_ELIGIBLE_V2','ALL_ELIGIBLE','SUPPORT_BILLING_SCOPE_V2','VERSION_AND_TIME_MISMATCH_V2','OPAQUE_JOURNEY_KEY','BRAND_JOURNEY_ID_HASH','ABANDONMENT_WITHIN_24H')~ok,'provenance configured'
call assertTrue c~seal~ok,'cohort seals'
t=.BrandEvidenceThreshold~new('JOURNEY-V06-PROV',500,50,20,10,14,1,1.2,80,95,.false,.true,100,0,0,.true)
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,t); call assertTrue r~ok,'analysis succeeds'; a=r~value
prov=a~frame~cohortProvenance
call assertTrue prov\==.nil,'provenance attached'
call assertTrue prov~sealed,'provenance sealed'
call assertEqual 1100,prov~sourceCandidateCount,'source candidates include rejected bucket units'
call assertEqual 1000,prov~selectedCount,'selected count'
call assertEqual 1000,prov~analyzableCount,'analyzable count'
call assertEqual 100,prov~excludedCount,'excluded count'
call assertEqual 'SUPPORT_BILLING_ELIGIBLE_V2',prov~selectionRuleId,'explicit selection rule survives'
call assertTrue a~assessment~cohortQualityGate,'v0.6 cohort quality gate passes'
call assertTrue a~assessment~status='SUPPORTED' | a~assessment~status='STRONG','supported evidence status'
text=a~frame~canonicalText
call assertTrue text~pos('EXCLUSION_REASON=MODEL_VERSION_MISMATCH:100')>0,'exclusion reason travels'
call assertTrue text~pos('OUTCOME_ASCERTAINMENT_ID=ABANDONMENT_WITHIN_24H')>0,'outcome ascertainment travels'
say 'PASS test_v06_cohort_provenance'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
