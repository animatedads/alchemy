pop=.BrandJourneyPopulation~new('pop')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-01-01T00:00:00Z','2026-02-28T23:59:59Z','SUPPORT','HIGH_SASS','ABANDONMENT',10000,300,500,50,'TONE7','STYLE04','PROC','MODEL',86400); b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C'); b~seal; pop~addBucket(b); pop~seal
c=.BrandJourneyCohortDefinition~new('c','CURRENT','SUPPORT','2026-01-01T00:00:00Z','2026-02-28T23:59:59Z',59,'HIGH_SASS','ABANDONMENT',86400,'TONE7','STYLE04','PROC','MODEL'); c~seal
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,.BrandEvidenceThreshold~new); rr=a~reasoningReport(ar~value)
binding=.BrandInterventionEvidenceBinding~new('old',rr~value,'2026-08-23T00:00:00Z',176,'CLOCK'); binding~seal
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:J5','2026-08-23T00:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',60,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
policy=.BrandInterventionPolicy~new('P',30); policy~addObligation('PRESERVE_TRUTHFULNESS'); policy~seal
r=.BrandInterventionEngine~new~decide(ctx,binding,policy); call assertTrue r~ok,'decision'; d=r~value
call assertEqual 'REVIEW_REQUIRED',d~mode,'stale evidence requires review/refresh'
call assertEqual 'REFRESH_STALE_EVIDENCE',d~proposal~proposalKind,'refresh proposal'
call assertTrue d~proposal~hasObjective('REFRESH_SCOPED_CURRENT_EVIDENCE'),'refresh'
call assertTrue d~proposal~hasAvoidance('ALTER_BEHAVIOUR_FROM_STALE_EVIDENCE'),'no stale adaptation'
say 'PASS test_stale_evidence_review'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
