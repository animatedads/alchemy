parse arg root portFile statusFile keyHex
service = .ShannonQueueService~new(.ShannonSocketTestSession~new)
gateway = .ShannonSocketIngressServer~new(service, keyHex)
call lineout portFile, gateway~port
call lineout portFile
serveOperation = gateway~serveOne
ignored = gateway~stop
if \serveOperation~ok then do
  call lineout statusFile, 'serve=FAIL;code=' || serveOperation~code || ';detail=' || serveOperation~detail
  call lineout statusFile
  exit 21
end
replyOperation = service~receive
if \replyOperation~ok then exit 22
reply = replyOperation~value~payload
auditOperation = service~getAudit
if \auditOperation~ok then exit 23
audit = auditOperation~value~payload
call lineout statusFile, 'serve=OK;mode=' || reply['mode'] || ';audit=' || audit['schema'] || ';fabric=' || audit['queue']['fabricVersion'] || ';indexed=' || service~auditCatalog~indexedCount || ';text=' || reply['text']
call lineout statusFile
exit 0

::class ShannonSocketTestTurn
::attribute turnNumber get
::attribute finalText get
::attribute mode get
::attribute auditRecord get

::method init
  expose turnNumber finalText mode auditRecord
  use arg text
  turnNumber = 1
  finalText = 'SOCKET_ECHO:' || text~string
  mode = 'TRANSPORT_TEST'
  auditRecord = .directory~new
  auditRecord['schema'] = 'ourladyair.shannon.turn.v3'
  auditRecord['sessionId'] = 'socket-transport-test'
  auditRecord['turn'] = 1
  booking = .directory~new
  booking['sourceFormat'] = 'TEST'
  booking['sourceEnvelopeStatus'] = 'NOT_APPLICABLE'
  auditRecord['booking'] = booking
  governance = .directory~new
  governance['mode'] = mode
  governance['hardWorldState'] = 'TRANSPORT_TEST'
  governance['salesAllowed'] = .false
  governance['legalApiVersion'] = 'TRANSPORT_TEST_NOT_EVALUATED'
  governance['legalGeneration'] = 'TRANSPORT-TEST-NOT-AUTHORITY'
  auditRecord['governance'] = governance
  commercial = .directory~new
  commercial['modelGrossCents'] = 0
  commercial['governedGrossCents'] = 0
  commercial['permittedCount'] = 0
  commercial['blockedCount'] = 0
  commercial['decisionViews'] = .array~new
  auditRecord['commercial'] = commercial
  auditRecord['finalText'] = finalText

::class ShannonSocketTestSession
::method respond
  use arg text
  return .ShannonSocketTestTurn~new(text)

::requires 'ShannonSocketGateway.cls'
