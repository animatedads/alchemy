now = .DateTime~new
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
snapshot = .ReputationTestSupport~snapshot('SNAP-CUSTOMER-COMMS', now, now, .array~of('GB'))~seal

/* Same unresolved customer state for both candidate responses. */
serviceFailure = .ReputationCommunicationFailure~new('F-SERVICE', 'SERVICE_RESPONSE_FAILURE', 'SUPPORT', 'OPEN', 70, 'Technical response consumed allowance but was not delivered')
safetyFailure = .ReputationCommunicationFailure~new('F-SAFETY', 'SAFETY_REPORT_UNANSWERED', 'SAFETY_INBOX', 'OPEN', 85, 'Safety correspondence has not received a response')

/* Candidate A: acknowledges limits, treats process failures as process failures, and stops selling. */
bubbaComm = .ReputationCommunicationSurface~new('COMM-BUBBA', 'PROSPECTIVE_CUSTOMER', 'UK_PUBLIC_BODY')
bubbaComm~addFailure(serviceFailure)
bubbaComm~addFailure(safetyFailure)
bubbaComm~addAct('ACKNOWLEDGEMENT', 'CUSTOMER_EVIDENCE', 'ACCEPTED')
bubbaComm~addAct('EVIDENCE_LIMIT', 'MODEL_VISIBILITY', 'NO_PRIOR_HISTORY')
bubbaComm~addAct('PROCESS_OWNERSHIP', 'CRM', 'RECORDS_PROBLEM')
bubbaComm~addAct('DECLARED_INTENT', '', 'STOP_SELLING')
bubbaComm~seal
bubbaAction = .ReputationActionSurface~new('RESPONSE-BUBBA', 'ETHICAL_INC', 'CUSTOMER_COMMUNICATION', now, 'NORMAL')
bubbaAction~addGeography('GB')
bubbaAction~addAudience('GENERAL_PUBLIC')
bubbaAction~setCommunicationSurface(bubbaComm)
bubbaAction~seal
bubbaDecision = .ReputationEngine~new~evaluate(bubbaAction, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'CLEAR', bubbaDecision~disposition, 'commercial restraint candidate stays clear'
call assertTrue bubbaDecision~containsCode('COMMERCIAL_RESTRAINT'), 'commercial restraint support retained'
call assertTrue bubbaDecision~containsCode('EVIDENTIAL_DISCIPLINE'), 'evidential discipline support retained'
call assertFalse bubbaDecision~containsCode('COMMERCIAL_PRESSURE_COLLISION'), 'no sales pressure concern'

/* Candidate B: says selling past the failure is wrong, but immediately asks for deal qualification and redirects to a failed route. */
claudeComm = .ReputationCommunicationSurface~new('COMM-CLAUDE-INITIAL', 'PROSPECTIVE_CUSTOMER', 'UK_PUBLIC_BODY')
claudeComm~addFailure(serviceFailure)
claudeComm~addFailure(safetyFailure)
claudeComm~addAct('DECLARED_INTENT', '', 'STOP_SELLING')
claudeComm~addAct('SALES_PROMPT', 'DEAL_QUALIFICATION', 'SEAT_COUNT')
claudeComm~addAct('SALES_PROMPT', 'DEAL_QUALIFICATION', 'BUYER_IDENTITY')
claudeComm~addAct('REDIRECT', 'SUPPORT', 'OPEN_SUPPORT_CASE')
claudeComm~seal
claudeAction = .ReputationActionSurface~new('RESPONSE-CLAUDE-INITIAL', 'VENDOR', 'CUSTOMER_COMMUNICATION', now, 'NORMAL')
claudeAction~addGeography('GB')
claudeAction~addAudience('GENERAL_PUBLIC')
claudeAction~setCommunicationSurface(claudeComm)
claudeAction~seal
claudeDecision = .ReputationEngine~new~evaluate(claudeAction, snapshot, catalog, graph)~value~geographicDecision('GB')
call assertEqual 'HOLD', claudeDecision~disposition, 'selling into unresolved failure is held'
call assertTrue claudeDecision~containsCode('COMMERCIAL_PRESSURE_COLLISION'), 'sales pressure collision detected'
call assertTrue claudeDecision~containsCode('PROCESS_CIRCULARITY'), 'redirect to failed support route detected'
call assertTrue claudeDecision~containsCode('DECLARED_INTENT_ACTION_MISMATCH'), 'declared stop selling conflicts with action'

say 'PASS test_reputation_communication_pair'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationTestSupport.cls'
