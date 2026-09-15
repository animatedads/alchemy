now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 2, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
event = .ReputationTestSupport~boeingIncident('BOEING-SCOT', eventTime, 'SERIOUS')
snapshot = .ReputationTestSupport~snapshot('SNAP-SCOT', now, now, .array~of('GB'), .array~of(event))~seal

action = .ReputationActionSurface~new('GLA-AD', 'OURLADYAIR', 'ADVERTISING', now, 'NORMAL')
action~addGeography('SCOTLAND')
action~addAssociation('MANUFACTURER', 'BOEING', 90)
action~addConcept('EXTRA_LEGROOM')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('SCOTLAND')
call assertTrue decision~disposition \== 'CLEAR', 'GB descendant propagation reaches Scotland'
call assertTrue decision~containsCode('CONTEXTUAL_SEMANTIC_COLLISION'), 'propagated event evaluated'
say 'PASS test_reputation_geography_propagation'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'ReputationTestSupport.cls'
