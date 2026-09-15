/* Large population without creating 29,234 live journey objects. */
p=.BrandJourneyPopulation~new('support-billing-q3')
b=.BrandJourneyPopulationAggregateBucket~new('q3','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','SUPPORT_TO_BILLING_UNRESOLVED','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',29234,109,500,20,'JOURNEY-CLASSIFIER-V3','JOURNEY-TAXONOMY-0.1','PROCESS-7','MODEL-4',86400)
b~addSupportPoint('BRAND_JOURNEY:CASE:SUPPORT-17'); b~addCounterPoint('BRAND_JOURNEY:CASE:COUNTER-22'); b~seal; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('q3','CURRENT','SUPPORT_TO_BILLING_UNRESOLVED','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JOURNEY-CLASSIFIER-V3','JOURNEY-TAXONOMY-0.1','PROCESS-7','MODEL-4'); c~seal
t=.BrandEvidenceThreshold~new('JOURNEY-V1',1000,25,20,5,14,1,1.25,80)
a=.BrandJourneyPopulationAnalyzer~new
r=a~analyze(p,c,t)
if \r~ok then do; say 'analysis failed:' r~code; exit 1; end
rr=a~reasoningReport(r~value)
if \rr~ok then do; say 'report failed:' rr~code; exit 1; end
say rr~value~reasoningMaterial
::requires 'BrandJourneyPopulation.cls'
