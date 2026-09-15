p=.BrandJourneyPopulation~new('provenance')
b1=.BrandJourneyPopulationAggregateBucket~new('match','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z','SUPPORT_TO_BILLING','CUSTOMER_REPEAT_BURDEN','ABANDONMENT',1000,30,100,20,'JV3','JT1','PROC-7','MODEL-6.4',86400); b1~addSupportPoint('BRAND_JOURNEY:CASE:MATCH-S'); b1~addCounterPoint('BRAND_JOURNEY:CASE:MATCH-C'); b1~seal; p~addBucket(b1)
b2=.BrandJourneyPopulationAggregateBucket~new('old-model','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z','SUPPORT_TO_BILLING','CUSTOMER_REPEAT_BURDEN','ABANDONMENT',2000,60,200,40,'JV3','JT1','PROC-7','MODEL-6.3',86400); b2~seal; p~addBucket(b2); p~seal
c=.BrandJourneyCohortDefinition~new('new-model-only','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z',15,'CUSTOMER_REPEAT_BURDEN','ABANDONMENT',86400,'JV3','JT1','PROC-7','MODEL-6.4'); c~seal
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new('T',500,20,10,5,7,1,1.2,80)); call assertTrue r~ok,'analysis succeeds'
call assertEqual 3000,r~value~selection~totalInput,'all candidates audited'
call assertEqual 1000,r~value~selection~includedCount,'only matching release included'
call assertEqual 2000,r~value~selection~excludedModel,'old model excluded visibly'
call assertEqual 1000,r~value~frame~populationCount,'denominator cannot silently mix model releases'
say 'PASS test_cohort_provenance_selection'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
