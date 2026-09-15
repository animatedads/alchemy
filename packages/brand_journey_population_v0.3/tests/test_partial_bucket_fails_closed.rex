p=.BrandJourneyPopulation~new('partial')
b=.BrandJourneyPopulationAggregateBucket~new('quarter','2026-07-01T00:00:00Z','2026-09-30T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',10000,100,500,25,'JV3','JT1','PROC','MODEL',86400); b~seal; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('aug','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-31T23:59:59Z',31,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC','MODEL'); c~seal
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new); call assertTrue r~ok,'analysis returns explicit empty frame rather than prorating'
call assertEqual 0,r~value~frame~populationCount,'partial bucket not silently prorated'
call assertEqual 10000,r~value~selection~excludedPartialTimeBucket,'full partial bucket denominator reported as excluded'
call assertEqual 'INSUFFICIENT',r~value~assessment~status,'no evidence fabricated'
say 'PASS test_partial_bucket_fails_closed'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
