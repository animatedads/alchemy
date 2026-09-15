/* Synthetic demonstration only. */
pop=.BrandJourneyPopulation~new('sass-demo')
b=.BrandJourneyPopulationAggregateBucket~new('current','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','COMMERCIAL_EXIT',29234,109,500,20,'TONE7','STYLE04','PROC7','MODEL64',86400)
b~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:S1'); b~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:C1'); b~seal; pop~addBucket(b); pop~seal
cohort=.BrandJourneyCohortDefinition~new('current','CURRENT','UNRESOLVED_SUPPORT','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,'HIGH_SASS','COMMERCIAL_EXIT',86400,'TONE7','STYLE04','PROC7','MODEL64'); cohort~seal
an=.BrandJourneyPopulationAnalyzer~new; x=an~analyze(pop,cohort,.BrandEvidenceThreshold~new)~value; report=an~reasoningReport(x)~value
binding=.BrandInterventionEvidenceBinding~new('evidence',report,'2026-08-23T12:00:00Z',2,'DEMO_CLOCK'); binding~seal
ctx=.BrandInterventionContext~new('current-customer-state','BRAND_JOURNEY:DEMO','2026-08-23T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',70,.false); ctx~addBrandFunction('PROMOTIONAL_WORK'); ctx~addBrandOpportunity('RETENTION'); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
r=.BrandInterventionEngine~new~decide(ctx,binding)
if \r~ok then do; say 'FAIL' r~code r~detail; exit 1; end
say r~value~reasoningMaterial
::requires 'BrandIntervention.cls'
