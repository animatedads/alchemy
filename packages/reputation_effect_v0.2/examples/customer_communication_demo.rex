now = .DateTime~new
catalog = .ReputationTestSupport~geographyCatalog
graph = .ReputationTestSupport~conceptGraph
snapshot = .ReputationTestSupport~snapshot('SNAP-CUSTOMER', now, now, .array~of('GB'))~seal
serviceFailure = .ReputationCommunicationFailure~new('F-SERVICE','SERVICE_RESPONSE_FAILURE','SUPPORT','OPEN',70)
safetyFailure = .ReputationCommunicationFailure~new('F-SAFETY','SAFETY_REPORT_UNANSWERED','SAFETY_INBOX','OPEN',85)

commA=.ReputationCommunicationSurface~new('RESP-A','PROSPECTIVE_CUSTOMER','UK_PUBLIC_BODY')
commA~addFailure(serviceFailure); commA~addFailure(safetyFailure)
commA~addAct('ACKNOWLEDGEMENT','CUSTOMER_EVIDENCE','ACCEPTED')
commA~addAct('EVIDENCE_LIMIT','MODEL_VISIBILITY','NO_PRIOR_HISTORY')
commA~addAct('PROCESS_OWNERSHIP','CRM','RECORDS_PROBLEM')
commA~addAct('DECLARED_INTENT','','STOP_SELLING'); commA~seal
a=.ReputationActionSurface~new('CANDIDATE-A','VENDOR','CUSTOMER_COMMUNICATION',now,'NORMAL')
a~addGeography('GB'); a~addAudience('GENERAL_PUBLIC'); a~setCommunicationSurface(commA); a~seal

commB=.ReputationCommunicationSurface~new('RESP-B','PROSPECTIVE_CUSTOMER','UK_PUBLIC_BODY')
commB~addFailure(serviceFailure); commB~addFailure(safetyFailure)
commB~addAct('DECLARED_INTENT','','STOP_SELLING')
commB~addAct('SALES_PROMPT','DEAL_QUALIFICATION','SEAT_COUNT')
commB~addAct('REDIRECT','SUPPORT','OPEN_SUPPORT_CASE'); commB~seal
b=.ReputationActionSurface~new('CANDIDATE-B','VENDOR','CUSTOMER_COMMUNICATION',now,'NORMAL')
b~addGeography('GB'); b~addAudience('GENERAL_PUBLIC'); b~setCommunicationSurface(commB); b~seal

engine=.ReputationEngine~new
da=engine~evaluate(a,snapshot,catalog,graph)~value~geographicDecision('GB')
db=engine~evaluate(b,snapshot,catalog,graph)~value~geographicDecision('GB')
say 'candidate A=' da~disposition
call printItems da
say 'candidate B=' db~disposition
call printItems db
exit 0
printItems: procedure
  use arg decision
  do item over decision~items
    say '  ' item~itemKind item~code 'severity='item~severity
  end
  return
::requires 'ReputationTestSupport.cls'
