say .BrandJourneyPopulationBuild~PRODUCT .BrandJourneyPopulationBuild~VERSION
p=.BrandJourneyPopulation~new('p1')
o=.BrandJourneyPopulationObservation~new('o1','BRAND_JOURNEY:j1','2026-08-01T00:00:00Z','SUPPORT_TO_BILLING','ABANDONMENT',.false,0,'TONE-V1','TAX-1','PROC-1','MODEL-1')
o~addExposure('CROSS_DOMAIN_CONTEXT_LOSS'); call assertTrue o~seal~ok,'observation seals'; call assertTrue p~addObservation(o)~ok,'observation adds'; call assertTrue p~seal~ok,'population seals'
c=.BrandJourneyCohortDefinition~new('c1','CURRENT','SUPPORT_TO_BILLING','2026-08-01T00:00:00Z','2026-08-31T23:59:59Z',31,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'TONE-V1','TAX-1','PROC-1','MODEL-1'); call assertTrue c~seal~ok,'cohort seals'
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new('SMOKE',1,1,1,1,1,0,1,80)); call assertTrue r~ok,'analysis builds'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
