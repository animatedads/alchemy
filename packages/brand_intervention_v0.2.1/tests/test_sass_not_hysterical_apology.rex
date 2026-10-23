pop=.BrandJourneyPopulation~new('sass')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','COMMERCIAL_EXIT',30000,600,1000,100,'TONE7','STYLE04','PROC','MODEL64',86400); b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C'); b~seal; pop~addBucket(b); pop~seal
c=.BrandJourneyCohortDefinition~new('c','CURRENT','UNRESOLVED_SUPPORT','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'HIGH_SASS','COMMERCIAL_EXIT',86400,'TONE7','STYLE04','PROC','MODEL64'); c~seal
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,.BrandEvidenceThreshold~new); rr=a~reasoningReport(ar~value)
binding=.BrandInterventionEvidenceBinding~new('bnd',rr~value,'2026-08-23T00:00:00Z',2,'CLOCK'); binding~seal
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:J4','2026-08-23T00:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',70,.false); ctx~addBrandFunction('PROMOTIONAL_WORK'); ctx~addBrandOpportunity('RETENTION'); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
r=.BrandInterventionEngine~new~decide(ctx,binding); call assertTrue r~ok,'decision'; p=r~value~proposal
call assertEqual 'TONE_APPROPRIATENESS_GUIDANCE',p~proposalKind,'tone proposal'
call assertTrue p~hasObjective('REDUCE_DISMISSIVE_REGISTER'),'reduce dismissiveness'
call assertTrue p~hasObjective('MAINTAIN_SERVICE_ENGAGEMENT'),'keep engaged'
call assertTrue p~hasAvoidance('UNILATERAL_RELATIONAL_CLOSURE'),'avoid im done register'
call assertTrue p~hasAvoidance('EXTREME_APOLOGY_AS_DEFAULT_RECOVERY'),'sass does not teach hysterical apology'
call assertFalse p~hasObjective('APOLOGISE_EXTREMELY'),'no canned extreme apology'
call assertFalse p~hasObjective('OFFER_PRODUCT'),'service as sales does not create sales act'
say 'PASS test_sass_not_hysterical_apology'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
