now = .DateTime~new
oldRefresh = now - .TimeSpan~new(0, 0, 30, 0, 0)
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
snapshot = .ReputationTestSupport~snapshot('SNAP-STALE', now, oldRefresh, .array~of('GB'))~seal

action = .ReputationActionSurface~new('LIVE-CAMPAIGN', 'OURLADYAIR', 'ADVERTISING', now, 'LIVE_MAJOR_EVENT')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD_REFRESH_REQUIRED', decision~disposition, 'stale context fails closed'
call assertTrue decision~containsCode('WORLD_CONTEXT_STALE'), 'staleness reason retained'

unknownSnapshot = .ReputationTestSupport~snapshot('SNAP-UNKNOWN', now, now, .array~of('GR'))~seal
unknownAction = .ReputationActionSurface~new('GB-CAMPAIGN', 'OURLADYAIR', 'ADVERTISING', now, 'NORMAL')
unknownAction~addGeography('GB')
unknownAction~seal
unknownDecision = .ReputationEngine~new~evaluate(unknownAction, unknownSnapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD_REFRESH_REQUIRED', unknownDecision~disposition, 'unknown geographic coverage fails closed'
call assertTrue unknownDecision~containsCode('WORLD_CONTEXT_UNKNOWN'), 'unknown coverage reason retained'
say 'PASS test_reputation_freshness_unknown'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
