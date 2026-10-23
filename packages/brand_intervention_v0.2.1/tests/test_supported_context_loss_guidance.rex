pop=.BrandJourneyPopulation~new('pop')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','SUPPORT_TO_BILLING_UNRESOLVED','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',29234,109,500,20,'JV3','JT1','PROC7','MODEL4',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S1'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C1'); call assertTrue b~seal~ok,'bucket'; call assertTrue pop~addBucket(b)~ok,'add'; call assertTrue pop~seal~ok,'pop'
c=.BrandJourneyCohortDefinition~new('c','CURRENT','SUPPORT_TO_BILLING_UNRESOLVED','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC7','MODEL4'); call assertTrue c~seal~ok,'cohort'
t=.BrandEvidenceThreshold~new('T',1000,25,20,5,14,1,1.25,80)
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,t); call assertTrue ar~ok,'analysis'; rr=a~reasoningReport(ar~value); call assertTrue rr~ok,'report'
binding=.BrandInterventionEvidenceBinding~new('bind',rr~value,'2026-08-23T12:00:00Z',2,'CLOCK-AUTH'); call assertTrue binding~seal~ok,'binding'
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:J1','2026-08-23T12:00:00Z','BILLING','UNRESOLVED',.true,'FRUSTRATED',70,.false)
ctx~addFinding('CROSS_DOMAIN_CONTEXT_LOSS'); ctx~addFinding('CUSTOMER_REPEAT_BURDEN'); ctx~addBrandFunction('PROMOTIONAL_WORK'); ctx~addBrandOpportunity('RETENTION'); ctx~addObligation('PRESERVE_TRUTHFULNESS'); call assertTrue ctx~seal~ok,'context'
policy=.BrandInterventionPolicy~new('P',30); policy~addObligation('PRESERVE_TRUTHFULNESS'); policy~addProhibition('INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT'); call assertTrue policy~seal~ok,'policy'
dr=.BrandInterventionEngine~new~decide(ctx,binding,policy); call assertTrue dr~ok,'decision'; d=dr~value
call assertEqual 'REASONING_GUIDANCE',d~mode,'supported evidence permits reasoning guidance only'
call assertTrue d~proposal~hasObjective('RESTORE_RELEVANT_CONTEXT'),'restore context'
call assertTrue d~proposal~hasObjective('REDUCE_CUSTOMER_REPEAT_BURDEN'),'repeat burden'
call assertTrue d~proposal~hasObjective('RESOLVE_CURRENT_NEED_BEFORE_COMMERCIAL_TRANSITION'),'resolve before commercial transition'
call assertTrue d~proposal~hasAvoidance('INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT'),'brand tags do not confer sales authority'
call assertFalse d~proposal~hasObjective('OFFER_PRODUCT'),'no sales proposal generated'
text=d~reasoningMaterial
call assertTrue text~pos('POPULATION=29234')>0,'full denominator supplied to reasoning LLM'
call assertTrue text~pos('FROM=2026-06-01')>0,'time scope supplied'
call assertTrue text~pos('MIN_EXPOSED=25')>0,'threshold supplied'
call assertTrue text~pos('COUNTER_POINT=')>0,'counterweight supplied'
call assertTrue text~pos('GUIDANCE_NOT_EXECUTION')>0,'not execution'
say 'PASS test_supported_context_loss_guidance'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
