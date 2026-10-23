pop=.BrandJourneyPopulation~new('tiny')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-08-01T00:00:00Z','2026-08-03T23:59:59Z','SUPPORT','HIGH_SASS','ABANDONMENT',20,1,3,1,'JV3','JT1','PROC','MODEL',86400); b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C'); b~seal; pop~addBucket(b); pop~seal
c=.BrandJourneyCohortDefinition~new('c','CURRENT','SUPPORT','2026-08-01T00:00:00Z','2026-08-03T23:59:59Z',3,'HIGH_SASS','ABANDONMENT',86400,'JV3','JT1','PROC','MODEL'); c~seal
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,.BrandEvidenceThreshold~new); rr=a~reasoningReport(ar~value)
binding=.BrandInterventionEvidenceBinding~new('bnd',rr~value,'2026-08-04T00:00:00Z',1,'CLOCK'); binding~seal
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:J3','2026-08-04T00:00:00Z','SUPPORT','UNRESOLVED',.true,'ANGRY',50,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
r=.BrandInterventionEngine~new~decide(ctx,binding); call assertTrue r~ok,'decision'; d=r~value
call assertEqual 'BASELINE_ONLY',d~mode,'insufficient data cannot drive behaviour'
call assertTrue d~proposal~hasObjective('PRESERVE_BASELINE_SERVICE_BEHAVIOUR'),'baseline only objective'
call assertFalse d~proposal~hasObjective('REDUCE_DISMISSIVE_REGISTER'),'weak sample does not install style rule'
say 'PASS test_insufficient_baseline_only'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
