p=.BrandJourneyPopulation~new('lag-window')
o1=.BrandJourneyPopulationObservation~new('within','BRAND_JOURNEY:J1','2026-08-10T10:00:00Z','SUPPORT_TO_BILLING','ABANDONMENT',.true,3600,'JV3','JT1','PROC','MODEL'); o1~addExposure('CROSS_DOMAIN_CONTEXT_LOSS'); o1~seal; p~addObservation(o1)
o2=.BrandJourneyPopulationObservation~new('late','BRAND_JOURNEY:J2','2026-08-10T11:00:00Z','SUPPORT_TO_BILLING','ABANDONMENT',.true,259200,'JV3','JT1','PROC','MODEL'); o2~addExposure('CROSS_DOMAIN_CONTEXT_LOSS'); o2~seal; p~addObservation(o2)
o3=.BrandJourneyPopulationObservation~new('control','BRAND_JOURNEY:J3','2026-08-10T12:00:00Z','SUPPORT_TO_BILLING','ABANDONMENT',.false,0,'JV3','JT1','PROC','MODEL'); o3~seal; p~addObservation(o3)
p~seal
c=.BrandJourneyCohortDefinition~new('lag24','CURRENT','SUPPORT_TO_BILLING','2026-08-10T00:00:00Z','2026-08-11T00:00:00Z',1,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JV3','JT1','PROC','MODEL'); c~seal
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new('LOW',1,1,1,1,1,0,1,80)); call assertTrue r~ok,'analysis succeeds'
call assertEqual 1,r~value~frame~outcomeCount,'only within-window abandonment counts'
call assertEqual 1,r~value~selection~outcomeOutsideWindow,'late abandonment shown as excluded outcome'
say 'PASS test_outcome_window'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
