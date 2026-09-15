now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 2, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
event = .ReputationTestSupport~boeingIncident('BOEING-EJECT', eventTime, 'FATAL')
snapshot = .ReputationTestSupport~snapshot('SNAP-MILE', now, now, .array~of('GB'), .array~of(event))~seal

action = .ReputationActionSurface~new('GLA-SKG-FLATBED', 'OURLADYAIR', 'ADVERTISING', now, 'HIGH_REACH')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~addAssociation('MANUFACTURER', 'BOEING', 90)
action~addAssociation('EQUIPMENT', '737-MAX-9', 100)
action~addConcept('FLAT_BED')
action~addConcept('MILE_HIGH_CLUB')
action~addBehaviorClass('SEXUAL_HUMOUR')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD', decision~disposition, 'fatal ejection context holds mile-high creative'
call assertTrue decision~containsCode('CONTEXTUAL_SEMANTIC_COLLISION'), 'semantic collision is explicit'
say 'PASS test_reputation_mile_high_collision'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
