/* Shannon Queue Fabric topic/pub-sub acceptance.
 * This uses a lightweight turn stub: the test is about routing semantics and
 * retained rich terminal observations, not Legal Effect compilation.
 */
parse arg root
service = .ShannonQueueService~new(.ShannonTopicTestSession~new)
call assertEqual .QueueFabricBuild~VERSION, service~queueFabricVersion, 'loaded Queue Fabric identity retained'

putOperation = service~submit('Please sell everything')
call assertTrue putOperation~ok, 'submit succeeds'

allDepth = service~manager~depth('SHANNON.EVENTS.ALL', 'auditor')
call assertTrue allDepth~ok, 'all event depth visible'
call assertEqual 2, allDepth~value['ready'], 'governed + classification events fan out to all observer'

safetyDepth = service~manager~depth('SHANNON.EVENTS.SAFETY', 'safety-monitor')
call assertTrue safetyDepth~ok, 'safety event depth visible'
call assertEqual 1, safetyDepth~value['ready'], 'suppressed turn routes to safety hierarchy'

revenueDepth = service~manager~depth('SHANNON.EVENTS.REVENUE', 'revenue-monitor')
call assertTrue revenueDepth~ok, 'revenue event depth visible'
call assertEqual 0, revenueDepth~value['ready'], 'suppressed turn not routed to revenue hierarchy'

allBrowse = service~manager~browse('SHANNON.EVENTS.ALL', 'auditor')
call assertTrue allBrowse~ok, 'all-event browse succeeds'
call assertEqual 'GOVERNED_TURN', allBrowse~value~payload['kind'], 'first routed event is governed turn'
call assertEqual 'ourladyair/shannon/turn/governed', allBrowse~value~headers['oqf.topic.string'], 'topic hierarchy retained in queue header'
call assertTrue allBrowse~value~payload['audit']~hasIndex('booking'), 'rich audit object graph remains payload'

/* Terminal observations are retained objects.  A later subscription receives
   the current observation without Shannon inventing a terminal JSON API. */
observation = .directory~new
observation['screen'] = 'IBM_I_SIGNON'
observation['keyboard'] = 'UNLOCKED'
fields = .array~new
field = .directory~new
field['id'] = 'F0345'
field['row'] = 5
field['column'] = 25
field['length'] = 10
fields~append(field)
observation['fields'] = fields

terminalPublish = service~topicBus~publishTerminalObservation('PUB400', 'QPADEV0025', '1', observation, .true)
call assertTrue terminalPublish~ok, 'terminal observation publish succeeds'
terminalPackage = service~topicBus~receiveTerminalObservation
call assertTrue terminalPackage~ok, 'terminal observation reaches Shannon inbox'
call assertEqual 'IBM_I_SIGNON', terminalPackage~value~payload['observation']['screen'], 'rich terminal observation preserved'
call assertEqual 10, terminalPackage~value~payload['observation']['fields'][1]['length'], 'field structure preserved'

/* Add a subscriber after publication. Retained replay must deliver the same
   current observation to the late subscriber. */
createLate = service~manager~createQueue('TERMINAL.LATE', 'TEMPORARY', 'OURLADYAIR.TERMINAL', 10, 'shannon-admin')
call assertTrue createLate~ok, 'late terminal queue created'
lateSub = service~topicBus~topicFabric~subscribe('TERMINAL.LATE.CURRENT', 'SHANNON.TERMINAL', 'current/PUB400/QPADEV0025', 'TERMINAL.LATE', 'TEMPORARY', 'shannon-admin')
call assertTrue lateSub~ok, 'late terminal subscription created'
lateBrowse = service~manager~browse('TERMINAL.LATE', 'shannon-admin')
call assertTrue lateBrowse~ok, 'retained terminal observation replayed'
call assertEqual 'IBM_I_SIGNON', lateBrowse~value~payload['observation']['screen'], 'late replay retained rich object'
call assertEqual 1, lateBrowse~value~headers['oqf.topic.retained'], 'late delivery marked retained'


/* Queue topic metadata also projects cleanly through the loaded NoSQLServer.
   This is observability only; it is not Shannon's authority path. */
topicAdapter = .QueueTopicNoSQLAdapter~new(service~topicBus~topicFabric)
topicQuery = topicAdapter~query('shannon-admin', "SELECT topic_name,topic_string FROM mq_topics WHERE topic_name='SHANNON.TERMINAL'")
call assertEqual .Error~SUCCESS, topicQuery~status, 'topic NoSQL projection query succeeds'
call assertEqual 1, topicQuery~rows~items, 'terminal topic projected once'
call assertEqual 'ourladyair/terminal', topicQuery~rows[1]['topic_string'], 'terminal topic string projected'

say 'PASS test_shannon_topic_bus'
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::class ShannonTopicTestTurn
::attribute turnNumber get
::attribute finalText get
::attribute mode get
::attribute auditRecord get

::method init
  expose turnNumber finalText mode auditRecord
  turnNumber = 1
  finalText = 'NO SALE'
  mode = 'TEST_SUPPRESSED'
  auditRecord = .directory~new
  auditRecord['schema'] = 'ourladyair.shannon.turn.v3'
  auditRecord['sessionId'] = 'topic-test'
  auditRecord['turn'] = 1
  booking = .directory~new
  booking['sourceFormat'] = 'TEST'
  booking['sourceEnvelopeStatus'] = 'NOT_APPLICABLE'
  auditRecord['booking'] = booking
  governance = .directory~new
  governance['mode'] = mode
  governance['hardWorldState'] = 'TEST_SUPPRESSED'
  governance['salesAllowed'] = .false
  governance['legalApiVersion'] = .LegalEffectBuild~API_VERSION
  governance['legalGeneration'] = 'TOPIC-TEST-NOT-AUTHORITY'
  auditRecord['governance'] = governance
  commercial = .directory~new
  commercial['modelGrossCents'] = 1000
  commercial['governedGrossCents'] = 0
  commercial['permittedCount'] = 0
  commercial['blockedCount'] = 1
  commercial['decisionViews'] = .array~new
  auditRecord['commercial'] = commercial
  auditRecord['finalText'] = finalText

::class ShannonTopicTestSession
::method respond
  use arg text
  return .ShannonTopicTestTurn~new

::requires 'ShannonQueueService.cls'
::requires 'ObjectQueueTopicNoSQL.cls'
