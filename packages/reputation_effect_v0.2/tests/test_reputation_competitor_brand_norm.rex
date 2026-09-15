now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 4, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
embarrassment = .ReputationTestSupport~embarrassmentEvent('BA-EYE', eventTime)
snapshot = .ReputationTestSupport~snapshot('SNAP-VIRGIN', now, now, .array~of('GB'), .array~of(embarrassment))
snapshot~addBrandNorm(.ReputationBrandNorm~new('N-VIRGIN-MOCK', 'VIRGIN_ATLANTIC', 'GB', 'GENERAL_PUBLIC', 'COMPETITIVE_MOCKERY', 95, 90))
snapshot~addRelationship(.ReputationRelationship~new('R-VS-BA', 'VIRGIN_ATLANTIC', 'COMPETITOR', 'BRITISH_AIRWAYS', 'GB', 100))
snapshot~seal

action = .ReputationActionSurface~new('CHEEKY-BLIMP', 'VIRGIN_ATLANTIC', 'ADVERTISING', now, 'HIGH_REACH', 'BRITISH_AIRWAYS')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~addBehaviorClass('COMPETITIVE_MOCKERY')
action~addBehaviorClass('SEXUAL_HUMOUR')
action~addConcept('SEXUAL_HUMOUR')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'CLEAR', decision~disposition, 'historically expected competitor mockery remains clear for embarrassment'
call assertTrue decision~containsCode('BRAND_NORM_COHERENCE'), 'brand norm support is retained'
call assertFalse decision~containsCode('EXPLOITATION_OF_HUMAN_HARM'), 'no human-harm exploitation concern for embarrassment'
say 'PASS test_reputation_competitor_brand_norm'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
