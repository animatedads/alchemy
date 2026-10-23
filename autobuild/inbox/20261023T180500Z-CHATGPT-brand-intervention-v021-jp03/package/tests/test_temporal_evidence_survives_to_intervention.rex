p=.BrandJourneyPopulation~new('temporal')
b1=.BrandJourneyPopulationAggregateBucket~new('cur','2026-08-01T00:00:00Z','2026-08-14T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','COMMERCIAL_EXIT',4000,240,400,60,'TONE7','STYLE04','PROC8','MODEL64',86400); b1~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CS'); b1~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:CC'); b1~seal; p~addBucket(b1)
b2=.BrandJourneyPopulationAggregateBucket~new('prev','2026-07-18T00:00:00Z','2026-07-31T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','COMMERCIAL_EXIT',4000,80,80,4,'TONE7','STYLE04','PROC8','MODEL63',86400); b2~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:PS'); b2~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:PC'); b2~seal; p~addBucket(b2)
b3=.BrandJourneyPopulationAggregateBucket~new('base','2026-02-01T00:00:00Z','2026-07-17T23:59:59Z','UNRESOLVED_SUPPORT','HIGH_SASS','COMMERCIAL_EXIT',50000,1000,500,25,'TONE7','STYLE04','PROC7','MODEL63',86400); b3~addSupportPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:BS'); b3~addCounterPoint('BRAND_JOURNEY:POPULATION_OBSERVATION:BC'); b3~seal; p~addBucket(b3); p~seal
cur=.BrandJourneyCohortDefinition~new('cur','CURRENT','UNRESOLVED_SUPPORT','2026-08-01T00:00:00Z','2026-08-14T23:59:59Z',14,'HIGH_SASS','COMMERCIAL_EXIT',86400,'TONE7','STYLE04','PROC8','MODEL64'); cur~seal
prev=.BrandJourneyCohortDefinition~new('prev','PREVIOUS','UNRESOLVED_SUPPORT','2026-07-18T00:00:00Z','2026-07-31T23:59:59Z',14,'HIGH_SASS','COMMERCIAL_EXIT',86400,'TONE7','STYLE04','PROC8','MODEL63'); prev~seal
base=.BrandJourneyCohortDefinition~new('base','LONG_BASELINE','UNRESOLVED_SUPPORT','2026-02-01T00:00:00Z','2026-07-17T23:59:59Z',167,'HIGH_SASS','COMMERCIAL_EXIT',86400,'TONE7','STYLE04','PROC7','MODEL63'); base~seal
a=.BrandJourneyPopulationAnalyzer~new; tr=a~temporalReport(p,cur,prev,base,.BrandEvidenceThreshold~new); call assertTrue tr~ok,'temporal report'
bind=.BrandInterventionEvidenceBinding~new('temporal-bind',tr~value,'2026-08-15T12:00:00Z',1,'CLOCK'); bind~seal
ctx=.BrandInterventionContext~new('ctx','BRAND_JOURNEY:TEMP','2026-08-15T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',70,.false); ctx~addObligation('PRESERVE_TRUTHFULNESS'); ctx~seal
r=.BrandInterventionEngine~new~decide(ctx,bind); call assertTrue r~ok,'decision'; text=r~value~reasoningMaterial
call assertTrue text~pos('MODEL_VERSION=MODEL64')>0,'current release supplied'
call assertTrue text~pos('MODEL_VERSION=MODEL63')>0,'comparison release supplied'
call assertTrue text~pos('CURRENT_V_PREVIOUS_EXPOSED_OUTCOME_RATE_DELTA_PCT')>0,'temporal change supplied'
call assertTrue text~pos('PREVIOUS_WINDOW_BEGIN')>0,'previous denominator not flattened away'
call assertTrue text~pos('BASELINE_WINDOW_BEGIN')>0,'baseline denominator not flattened away'
say 'PASS test_temporal_evidence_survives_to_intervention'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandIntervention.cls'
