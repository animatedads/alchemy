now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 4, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
fatalEvent = .ReputationTestSupport~fatalCompetitorEvent('BA-FATAL', eventTime)
snapshot = .ReputationTestSupport~snapshot('SNAP-FATAL', now, now, .array~of('GB'), .array~of(fatalEvent))
snapshot~addBrandNorm(.ReputationBrandNorm~new('N-VIRGIN-MOCK', 'VIRGIN_ATLANTIC', 'GB', 'GENERAL_PUBLIC', 'COMPETITIVE_MOCKERY', 95, 90))
snapshot~addRelationship(.ReputationRelationship~new('R-VS-BA', 'VIRGIN_ATLANTIC', 'COMPETITOR', 'BRITISH_AIRWAYS', 'GB', 100))
snapshot~seal

action = .ReputationActionSurface~new('DOORS-STAY-ON', 'VIRGIN_ATLANTIC', 'ADVERTISING', now, 'HIGH_REACH', 'BRITISH_AIRWAYS')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~addBehaviorClass('COMPETITIVE_MOCKERY')
action~addConcept('AIRCRAFT_CABIN')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD', decision~disposition, 'brand licence does not erase fatal-human-harm concern'
call assertTrue decision~containsCode('EXPLOITATION_OF_HUMAN_HARM'), 'human harm boundary explicit'
say 'PASS test_reputation_human_harm_boundary'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
