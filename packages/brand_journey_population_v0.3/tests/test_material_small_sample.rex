p=.BrandJourneyPopulation~new('enterprise-small')
b=.BrandJourneyPopulationAggregateBucket~new('enterprise-bucket','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z','ENTERPRISE_SUPPORT_HANDOFF','CUSTOMER_REPEAT_BURDEN','COMMERCIAL_EXIT',7,4,5,3,'JOURNEY-V3','JTAX-1','PROC-8','MODEL-5',604800)
b~setMateriality(95,4,2400000); b~addSupportPoint('BRAND_JOURNEY:ENTERPRISE:CASE-1'); b~addCounterPoint('BRAND_JOURNEY:ENTERPRISE:CASE-7'); b~seal; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('enterprise-week','CURRENT','ENTERPRISE_SUPPORT_HANDOFF','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z',7,'CUSTOMER_REPEAT_BURDEN','COMMERCIAL_EXIT',604800,'JOURNEY-V3','JTAX-1','PROC-8','MODEL-5'); c~seal
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new('ENTERPRISE',1000,25,20,5,14,1,1.25,80)); call assertTrue r~ok,'analysis succeeds'
a=r~value~assessment
call assertFalse a~statisticalSufficient,'tiny sample not statistically sufficient'
call assertTrue a~materialInvestigation,'material significance retained'
call assertEqual 'MATERIAL_INVESTIGATION',a~status,'small important sample gets investigation status'
say 'PASS test_material_small_sample'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
