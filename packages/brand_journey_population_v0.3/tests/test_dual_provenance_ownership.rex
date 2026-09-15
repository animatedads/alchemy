p=.BrandJourneyPopulation~new('dual-prov')
call assertTrue p~configureSourceProvenance('ANALYTICS_STORE','NOSQLSERVER_V077','JOURNEY','CONVENIENCE','OPAQUE_JOURNEY_ID','JOURNEY_ID_HASH')~ok,'population source provenance configured'

b=.BrandJourneyPopulationAggregateBucket~new('current','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',2000,80,200,30,'JV4','JT2','PROC-9','MODEL-7',86400)
b~addSupportPoint('BRAND_JOURNEY:CASE:SUPPORT')
b~addCounterPoint('BRAND_JOURNEY:CASE:COUNTER')
call assertTrue b~seal~ok,'bucket seals'; call assertTrue p~addBucket(b)~ok,'bucket adds'
/* Local duplicate attempt is evidence, but the rejected duplicate is not added to the denominator. */
call assertTrue \p~addBucket(b)~ok,'duplicate bucket rejected'
call assertTrue p~seal~ok,'population seals'

c=.BrandJourneyCohortDefinition~new('dual-current','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z',20,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV4','JT2','PROC-9','MODEL-7')
call assertTrue c~configureSelectionProvenance('SUPPORT_BILLING_COHORT_V3','INCLUDE_MATCHING_SCOPE','EXCLUDE_OUT_OF_SCOPE','ABANDONMENT_EVENT_V1')~ok,'cohort selection provenance configured'
call assertTrue c~seal~ok,'cohort seals'

t=.BrandEvidenceThreshold~new('V06-PROVENANCE',1000,25,20,5,14,1,1.25,80,95,.false,.true,100,0,0,.true)
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,t); call assertTrue r~ok,'analysis succeeds'; a=r~value
prov=a~frame~cohortProvenance
call assertEqual 'ANALYTICS_STORE',prov~sourceKind,'source kind comes from population'
call assertEqual 'NOSQLSERVER_V077',prov~sourceSystem,'source system comes from population'
call assertEqual 'CONVENIENCE',prov~samplingMethod,'sampling comes from population without moralizing'
call assertEqual 'SUPPORT_BILLING_COHORT_V3',prov~selectionRuleId,'selection rule comes from cohort'
call assertEqual 'INCLUDE_MATCHING_SCOPE',prov~inclusionPolicyId,'inclusion rule comes from cohort'
call assertEqual 'ABANDONMENT_EVENT_V1',prov~outcomeAscertainmentId,'outcome ascertainment comes from cohort'
call assertEqual 2000,prov~sourceCandidateCount,'rejected duplicate does not inflate source candidates'
call assertEqual 1,prov~duplicateCount,'rejected duplicate remains provenance evidence'
call assertTrue a~assessment~cohortQualityGate,'convenience sampling alone is not moralized into bad cohort quality'
say 'PASS test_dual_provenance_ownership'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
