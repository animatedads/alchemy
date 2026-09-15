pop=.BrandJourneyPopulation~new('small')
b=.BrandJourneyPopulationAggregateBucket~new('b','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z','ENTERPRISE_SUPPORT','CROSS_DOMAIN_CONTEXT_LOSS','COMMERCIAL_EXIT',7,4,5,4,'JV3','JT1','PROC7','MODEL4',86400)
b~setMateriality(95,4,2400000); b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S1'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C1'); call assertTrue b~seal~ok,'bucket'; call assertTrue pop~addBucket(b)~ok,'add'; call assertTrue pop~seal~ok,'pop'
c=.BrandJourneyCohortDefinition~new('c','CURRENT','ENTERPRISE_SUPPORT','2026-08-01T00:00:00Z','2026-08-07T23:59:59Z',7,'CROSS_DOMAIN_CONTEXT_LOSS','COMMERCIAL_EXIT',86400,'JV3','JT1','PROC7','MODEL4'); call assertTrue c~seal~ok,'cohort'
a=.BrandJourneyPopulationAnalyzer~new; ar=a~analyze(pop,c,.BrandEvidenceThreshold~new); call assertTrue ar~ok,'analysis'; call assertEqual 'MATERIAL_INVESTIGATION',ar~value~assessment~status,'material status'; rr=a~reasoningReport(ar~value); call assertTrue rr~ok,'report'
binding=.BrandInterventionEvidenceBinding~new('bnd',rr~value,'2026-08-08T12:00:00Z',1,'CLOCK'); binding~seal
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:J2','2026-08-08T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',90,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
r=.BrandInterventionEngine~new~decide(ctx,binding); call assertTrue r~ok,'decision'; d=r~value
call assertEqual 'REVIEW_REQUIRED',d~mode,'small material signal is review only'
call assertEqual 'INVESTIGATE_MATERIAL_SIGNAL',d~proposal~proposalKind,'investigation proposal'
call assertTrue d~proposal~hasAvoidance('AUTOMATIC_BEHAVIOUR_CHANGE_FROM_MATERIALITY_ONLY'),'no auto adaptation'
call assertTrue d~proposal~hasAvoidance('GENERALISE_SMALL_SAMPLE'),'no population generalisation'
say 'PASS test_material_signal_review_only'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
