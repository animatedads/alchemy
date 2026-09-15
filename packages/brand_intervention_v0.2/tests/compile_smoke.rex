p=.BrandInterventionPolicy~new('SMOKE',30); p~addObligation('PRESERVE_TRUTHFULNESS'); call assertTrue p~seal~ok,'policy'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandIntervention.cls'
::requires 'BrandInterventionJourneyBridge.cls'
::requires 'BrandInterventionPopulationBridge.cls'
