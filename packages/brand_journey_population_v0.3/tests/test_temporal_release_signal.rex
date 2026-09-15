p=.BrandJourneyPopulation~new('temporal')
/* baseline: low context-loss prevalence and low exposed abandonment */
b0=.BrandJourneyPopulationAggregateBucket~new('baseline','2026-01-01T00:00:00Z','2026-06-30T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',5000,75,100,5,'JV3','JT1','PROC-6','MODEL-6.3',86400); b0~addSupportPoint('BRAND_JOURNEY:CASE:BASE-S'); b0~addCounterPoint('BRAND_JOURNEY:CASE:BASE-C'); b0~seal; p~addBucket(b0)
/* previous */
b1=.BrandJourneyPopulationAggregateBucket~new('previous','2026-07-01T00:00:00Z','2026-07-31T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',1000,15,20,1,'JV3','JT1','PROC-6','MODEL-6.3',86400); b1~addSupportPoint('BRAND_JOURNEY:CASE:PREV-S'); b1~addCounterPoint('BRAND_JOURNEY:CASE:PREV-C'); b1~seal; p~addBucket(b1)
/* current after release: context loss and exposed abandonment both jump */
b2=.BrandJourneyPopulationAggregateBucket~new('current','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',1000,30,100,20,'JV3','JT1','PROC-7','MODEL-6.4',86400); b2~addSupportPoint('BRAND_JOURNEY:CASE:CUR-S'); b2~addCounterPoint('BRAND_JOURNEY:CASE:CUR-C'); b2~seal; p~addBucket(b2); p~seal
c=.BrandJourneyCohortDefinition~new('cur','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z',15,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC-7','MODEL-6.4'); c~seal
pr=.BrandJourneyCohortDefinition~new('prev','PREVIOUS','SUPPORT_TO_BILLING','2026-07-01T00:00:00Z','2026-07-31T23:59:59Z',31,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC-6','MODEL-6.3'); pr~seal
ba=.BrandJourneyCohortDefinition~new('base','LONG_BASELINE','SUPPORT_TO_BILLING','2026-01-01T00:00:00Z','2026-06-30T23:59:59Z',181,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC-6','MODEL-6.3'); ba~seal
t=.BrandEvidenceThreshold~new('T',500,10,10,1,7,1,1.2,80)
r=.BrandJourneyPopulationAnalyzer~new~temporalReport(p,c,pr,ba,t); call assertTrue r~ok,'temporal report succeeds'
text=r~value~reasoningMaterial
call assertTrue text~pos('CURRENT_V_PREVIOUS_EXPOSED_OUTCOME_RATE_DELTA_PCT=15')>0,'current exposed outcome rate jumps 15 points'
call assertTrue text~pos('CURRENT_V_PREVIOUS_FEATURE_PREVALENCE_DELTA_PCT=8')>0,'current feature prevalence jumps 8 points'
call assertTrue text~pos('MODEL_VERSION=MODEL-6.4')>0,'current release provenance visible'
call assertTrue text~pos('MODEL_VERSION=MODEL-6.3')>0,'comparison release provenance visible'
say 'PASS test_temporal_release_signal'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
