now = .DateTime~new
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
snapshot = .ReputationTestSupport~snapshot('SNAP-CONSERVATIVE', now, now, .array~of('GB'))
snapshot~addBrandNorm(.ReputationBrandNorm~new('N-FLAG-SEX', 'SOBER_FLAG_CARRIER', 'GB', 'GENERAL_PUBLIC', 'SEXUAL_HUMOUR', 10, 10))
snapshot~seal

action = .ReputationActionSurface~new('ODD-JOKE', 'SOBER_FLAG_CARRIER', 'ADVERTISING', now, 'NORMAL')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~addBehaviorClass('SEXUAL_HUMOUR')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'REVIEW', decision~disposition, 'strong brand mismatch requires review'
call assertTrue decision~containsCode('BRAND_NORM_MISMATCH'), 'brand mismatch reason retained'
say 'PASS test_reputation_brand_mismatch'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
