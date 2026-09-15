now = .DateTime~new
anchor = .ReputationEvidenceAnchor~new('NEWS-LONDON','NEWS','synthetic report',now,90)
observation = .ReputationObservation~new('OBS-1','EVENT-1','GB','AR',anchor,now,80,'CORROBORATED','Reported in GB; claimed effect in AR')
call assertEqual 'GB', observation~observedGeographyId, 'source observation geography retained'
call assertEqual 'AR', observation~affectedGeographyId, 'affected geography retained independently'
call assertTrue observation~canonicalText~pos('OBSERVED_GEO') > 0, 'observation canonicalises both geographic roles'
say 'PASS test_reputation_observation_geography'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationEffect.cls'
