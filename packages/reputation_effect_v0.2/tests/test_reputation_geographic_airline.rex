now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 5, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
event = .ReputationTestSupport~boeingIncident('BOEING-GEO', eventTime, 'SERIOUS')
snapshot = .ReputationTestSupport~snapshot('SNAP-GEO', now, now, .array~of('GB','GR'), .array~of(event))~seal

action = .ReputationActionSurface~new('AD-1', 'OURLADYAIR', 'ADVERTISING', now, 'NORMAL')
action~addGeography('GB')
action~addGeography('GR')
action~addAudience('GENERAL_PUBLIC')
action~addAssociation('MANUFACTURER', 'BOEING', 90)
action~addAssociation('EQUIPMENT', '737-MAX-9', 100)
action~addAssociation('SECTOR', 'AVIATION', 25)
action~addConcept('EXTRA_LEGROOM')
action~seal

outcome = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)
call assertTrue outcome~ok, 'evaluation succeeds'
decision = outcome~value
call assertEqual 'GEOGRAPHICALLY_CONFLICTED', decision~overallDisposition, 'same creative differs geographically'
call assertEqual 'HOLD', decision~geographicDecision('GB')~disposition, 'GB high-salience direct association holds'
call assertEqual 'WARN', decision~geographicDecision('GR')~disposition, 'GR lower salience only warns'
call assertTrue decision~geographicDecision('GB')~containsCode('CONTEXTUAL_SEMANTIC_COLLISION'), 'GB semantic collision retained'
say 'PASS test_reputation_geographic_airline'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationTestSupport.cls'
