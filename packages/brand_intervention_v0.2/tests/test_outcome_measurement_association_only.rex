o=.BrandInterventionOutcomeObservation~new('o1','BRAND_JOURNEY:J6','BRAND_INTERVENTION:PROPOSAL:P1','SERVICE_RECOVERY_GUIDANCE',.true,'2026-08-23T12:30:00Z','RELATIONSHIP_PRESERVED',.true,1800); o~addEvidencePoint('BRAND_JOURNEY:ASSESSMENT:A1'); call assertTrue o~seal~ok,'outcome seals'
call assertEqual 'ASSOCIATION_ONLY',o~causalStatus,'outcome observation cannot claim intervention worked'
r=.BrandInterventionPopulationBridge~new~toPopulationObservation('pop-o1',o,'SUPPORT_RECOVERY','JCLASS','JTAX','PROC','MODEL'); call assertTrue r~ok,'population bridge'; p=r~value
call assertTrue p~hasExposure('INTERVENTION_SERVICE_RECOVERY_GUIDANCE'),'intervention retained as exposure'
call assertTrue p~hasModifier('INTERVENTION_MEASUREMENT'),'measurement modifier'
call assertEqual 'RELATIONSHIP_PRESERVED',p~outcomeKind,'outcome retained'
say 'PASS test_outcome_measurement_association_only'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
::requires 'BrandInterventionPopulationBridge.cls'
