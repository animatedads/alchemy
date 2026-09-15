p=.BrandJourneyPopulation~new('default-prov')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z','SUPPORT_TO_BILLING','CUSTOMER_REPEAT_BURDEN','ABANDONMENT',100,5,20,3,'JV4','JT2','PROC-9','MODEL-7',86400)
b~seal; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('default','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z',7,'CUSTOMER_REPEAT_BURDEN','ABANDONMENT',86400,'JV4','JT2','PROC-9','MODEL-7'); c~seal
t=.BrandEvidenceThreshold~new('DEFAULT-PROV',1,1,1,1,1,0,1,80,95,.false,.true,0,100,100,.true)
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,t); call assertTrue r~ok,'default provenance is explicit and analyzable'
prov=r~value~frame~cohortProvenance
call assertEqual 'UNSPECIFIED',prov~sourceSystem,'unknown source system is not invented'
call assertEqual 'UNSPECIFIED',prov~samplingMethod,'unknown sampling method is not invented'
call assertEqual 'UNSPECIFIED',prov~deduplicationMethod,'unknown dedup method is not invented'
text=prov~canonicalText
call assertTrue text~pos('COHORT_LIMITATION=UPSTREAM_SOURCE_SYSTEM_UNSPECIFIED')>0,'unknown source limitation retained'
call assertTrue text~pos('COHORT_LIMITATION=SAMPLING_METHOD_UNSPECIFIED')>0,'unknown sampling limitation retained'
call assertTrue text~pos('COHORT_LIMITATION=UPSTREAM_DEDUPLICATION_UNSPECIFIED')>0,'unknown dedup limitation retained'
call assertTrue text~pos('COHORT_LIMITATION=PREAGGREGATED_BUCKETS_RELY_ON_UPSTREAM_COUNT_PROVENANCE')>0,'aggregate lineage limitation retained'
say 'PASS test_default_upstream_provenance_limitations'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
