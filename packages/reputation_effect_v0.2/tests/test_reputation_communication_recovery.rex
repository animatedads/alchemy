now = .DateTime~new
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
snapshot = .ReputationTestSupport~snapshot('SNAP-RECOVERY', now, now, .array~of('GB'))~seal
serviceFailure = .ReputationCommunicationFailure~new('F-SERVICE', 'SERVICE_RESPONSE_FAILURE', 'SUPPORT', 'OPEN', 70)

comm = .ReputationCommunicationSurface~new('COMM-CORRECTED', 'PROSPECTIVE_CUSTOMER', 'UK_PUBLIC_BODY', 'COMM-INITIAL')
comm~addFailure(serviceFailure)
comm~addAct('RETRACTION', 'PRIOR_CLAIM', 'EXPECTED_ON_FREE')
comm~addAct('CORRECTIVE_STATEMENT', 'PRIOR_CLAIM', 'NOT_SUPPORTED_BY_FACTS')
comm~addAct('EVIDENCE_LIMIT', 'ROOT_CAUSE', 'UNKNOWN')
comm~addAct('PROCESS_OWNERSHIP', 'CUSTOMER_PROCESS', 'FAILURE_ACKNOWLEDGED')
comm~addAct('ACKNOWLEDGEMENT', 'CUSTOMER_EVIDENCE', 'ACCEPTED')
comm~addAct('DECLARED_INTENT', '', 'STOP_SELLING')
comm~addAct('PROCUREMENT_INFO', 'PURCHASE_ROUTE', 'PUBLIC_INFORMATION')
comm~seal

action = .ReputationActionSurface~new('RESPONSE-CORRECTED', 'VENDOR', 'CUSTOMER_COMMUNICATION', now, 'NORMAL')
action~addGeography('GB')
action~addAudience('GENERAL_PUBLIC')
action~setCommunicationSurface(comm)
action~seal

decision = .ReputationEngine~new~evaluate(action, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'WARN', decision~disposition, 'corrected response recovers but commercial continuation still warns'
call assertTrue decision~containsCode('REPUTATIONAL_RECOVERY'), 'explicit correction is represented as recovery support'
call assertTrue decision~containsCode('EVIDENTIAL_DISCIPLINE'), 'evidential discipline retained'
call assertTrue decision~containsCode('DECLARED_INTENT_ACTION_MISMATCH'), 'procurement continuation conflicts with stop-selling declaration'
call assertFalse decision~containsCode('COMMERCIAL_PRESSURE_COLLISION'), 'information without a sales prompt is not treated as direct pressure'
say 'PASS test_reputation_communication_recovery'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
