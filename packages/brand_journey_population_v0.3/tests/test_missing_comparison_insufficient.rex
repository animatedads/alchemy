/* A one-arm/empty cohort is evidence about insufficiency, not a runtime error.
   BIE v0.6 requires a real 2x2 comparison arm for statistical association. */
p=.BrandJourneyPopulation~new('one-arm')
b=.BrandJourneyPopulationAggregateBucket~new('all-exposed','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z','SUPPORT_TO_BILLING','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',100,10,100,10,'JV6','JT6','PROC','MODEL',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:ONE-ARM-1'); call assertTrue b~seal~ok,'bucket seals'; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('one-arm-current','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-20T23:59:59Z',20,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV6','JT6','PROC','MODEL'); c~seal
t=.BrandEvidenceThreshold~new('ONE-ARM',50,20,5,5,14,1,1.2,80,95,.true,.true,100,0,0,.true)
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,t); call assertTrue r~ok,'analysis returns insufficiency rather than failure'; x=r~value
call assertEqual 'INSUFFICIENT',x~assessment~status,'one-arm evidence is insufficient'
call assertFalse x~assessment~statisticalSufficient,'one arm is not statistically sufficient'
call assertFalse x~uncertainty~comparisonAvailable,'local uncertainty marks missing comparison'
call assertContains x~assessment~reasons,'STATISTICAL_COMPARISON_GROUP_REQUIRED','comparison reason'
call assertContains x~assessment~reasons,'UNEXPOSED_COMPARISON_GROUP_EMPTY','empty comparison reason'
call assertTrue x~frame~cohortProvenance\==.nil,'cohort provenance still attached'
rr=.BrandJourneyPopulationAnalyzer~new~reasoningReport(x); call assertTrue rr~ok,'reasoning packet still builds'
text=rr~value~reasoningMaterial
call assertTrue text~pos('STATISTICAL_COMPARISON_GROUP_REQUIRED')>0,'insufficiency travels to reasoning LLM'
call assertTrue text~pos('COHORT_PROVENANCE=JOURNEY-one-arm-current')>0,'cohort construction travels despite insufficiency'
say 'PASS test_missing_comparison_insufficient'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then return; end; say 'FAIL:' label 'missing='needle; exit 1
::requires 'BrandJourneyPopulation.cls'
