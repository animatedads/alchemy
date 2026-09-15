now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 3, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
event = .ReputationTestSupport~boeingIncident('BOEING-DIST', eventTime, 'SERIOUS')
snapshot = .ReputationTestSupport~snapshot('SNAP-DIST', now, now, .array~of('GB'), .array~of(event))~seal

ourLady = .ReputationActionSurface~new('OLA-EXTRA', 'OURLADYAIR', 'ADVERTISING', now, 'NORMAL')
ourLady~addGeography('GB')
ourLady~addAudience('GENERAL_PUBLIC')
ourLady~addAssociation('MANUFACTURER', 'BOEING', 90)
ourLady~addAssociation('EQUIPMENT', '737-MAX-9', 100)
ourLady~addAssociation('SECTOR', 'AVIATION', 25)
ourLady~addConcept('EXTRA_LEGROOM')
ourLady~seal

flyLo = .ReputationActionSurface~new('FLYLO-EXTRA', 'FLYLO', 'ADVERTISING', now, 'NORMAL')
flyLo~addGeography('GB')
flyLo~addAudience('GENERAL_PUBLIC')
flyLo~addAssociation('MANUFACTURER', 'AIRBUS', 100)
flyLo~addAssociation('EQUIPMENT', 'A320', 100)
flyLo~addAssociation('SECTOR', 'AVIATION', 25)
flyLo~addConcept('EXTRA_LEGROOM')
flyLo~seal

engine = .ReputationEngine~new
olaDecision = engine~evaluate(ourLady, snapshot, catalog, graph)~value~geographicDecision('GB')
flyDecision = engine~evaluate(flyLo, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD', olaDecision~disposition, 'affected manufacturer and type holds'
call assertTrue flyDecision~disposition \== 'HOLD', 'unaffected manufacturer is not treated as directly exposed'
call assertTrue olaDecision~containsCode('DIRECT_EVENT_ASSOCIATION'), 'direct event association detected'
call assertFalse flyDecision~containsCode('DIRECT_EVENT_ASSOCIATION'), 'Airbus action does not inherit Boeing direct association'
say 'PASS test_reputation_manufacturer_distance'
exit 0

assertTrue: procedure
  use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure
  use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure
  use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
