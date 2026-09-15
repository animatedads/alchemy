now = .DateTime~new
eventTime = now - .TimeSpan~new(0, 0, 0, 10, 0)
beforeTime = eventTime - .TimeSpan~new(0, 0, 0, 5, 0)
afterTime = eventTime + .TimeSpan~new(0, 0, 0, 5, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
event = .ReputationTestSupport~boeingIncident('BOEING-REPLAY', eventTime, 'SERIOUS')

beforeSnapshot = .ReputationTestSupport~snapshot('SNAP-BEFORE', beforeTime, beforeTime, .array~of('GB'))~seal
beforeAction = .ReputationActionSurface~new('REPLAY-AD-BEFORE', 'OURLADYAIR', 'ADVERTISING', beforeTime, 'NORMAL')
beforeAction~addGeography('GB')
beforeAction~addAssociation('MANUFACTURER', 'BOEING', 90)
beforeAction~addConcept('EXTRA_LEGROOM')
beforeAction~seal
beforeDecision = .ReputationEngine~new~evaluate(beforeAction, beforeSnapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'CLEAR', beforeDecision~disposition, 'pre-event replay remains clear'

afterSnapshot = .ReputationTestSupport~snapshot('SNAP-AFTER', afterTime, afterTime, .array~of('GB'), .array~of(event))~seal
afterAction = .ReputationActionSurface~new('REPLAY-AD-AFTER', 'OURLADYAIR', 'ADVERTISING', afterTime, 'NORMAL')
afterAction~addGeography('GB')
afterAction~addAssociation('MANUFACTURER', 'BOEING', 90)
afterAction~addConcept('EXTRA_LEGROOM')
afterAction~seal
afterDecision = .ReputationEngine~new~evaluate(afterAction, afterSnapshot, catalog, graph)~value~geographicDecision('GB')
call assertTrue afterDecision~disposition \== 'CLEAR', 'same theme after event is no longer clear'
call assertTrue afterDecision~containsCode('CONTEXTUAL_SEMANTIC_COLLISION'), 'post-event collision retained'
say 'PASS test_reputation_temporal_replay'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
