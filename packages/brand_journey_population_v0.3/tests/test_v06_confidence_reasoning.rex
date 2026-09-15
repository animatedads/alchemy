/* BIE v0.6 statistical method/confidence material must survive into the
   journey reasoning packet rather than being replaced by a naked status. */
p=.BrandJourneyPopulation~new('confidence-pop')
b=.BrandJourneyPopulationAggregateBucket~new('confidence','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','SUPPORT_TO_BILLING_UNRESOLVED','CUSTOMER_REPEAT_BURDEN','ABANDONMENT',29234,109,500,20,'JOURNEY-V6','JTAX-2','PROC-9','MODEL-7',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CONF-1'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CONF-2'); b~seal; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('confidence-current','CURRENT','SUPPORT_TO_BILLING_UNRESOLVED','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'CUSTOMER_REPEAT_BURDEN','ABANDONMENT',86400,'JOURNEY-V6','JTAX-2','PROC-9','MODEL-7'); c~seal
t=.BrandEvidenceThreshold~new('CONF-V06',1000,25,20,5,14,1,1.25,80,95,.true,.true,100,0,0,.true)
a=.BrandJourneyPopulationAnalyzer~new
r=a~analyze(p,c,t); call assertTrue r~ok,'analysis succeeds'; x=r~value
call assertTrue x~assessment~statisticalEvidence\==.nil,'BIE v0.6 statistical evidence present'
rr=a~reasoningReport(x); call assertTrue rr~ok,'reasoning packet builds'
text=rr~value~reasoningMaterial
call assertTrue text~pos('STATISTICAL_METHOD=LOG_RR_PLUS_WILSON_RISK_DIFFERENCE_APPROXIMATION')>0,'statistical method travels'
call assertTrue text~pos('CONFIDENCE_LEVEL_PCT=95')>0,'confidence level travels'
call assertTrue text~pos('RELATIVE_RISK_CI_LOW=')>0,'relative-risk confidence bounds travel'
call assertTrue text~pos('RISK_DIFFERENCE_CI_LOW_PCT=')>0,'risk-difference bounds travel'
call assertTrue text~pos('COHORT_QUALITY_GATE=1')>0,'cohort quality result travels'
say 'PASS test_v06_confidence_reasoning'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
