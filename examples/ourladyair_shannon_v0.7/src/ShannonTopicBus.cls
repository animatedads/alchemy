/* Queue Fabric topic wiring for Shannon.
 *
 * Topics are deliberately a routing/observation layer over ordinary queues.
 * They do not become authority for Legal Effect or HardWorld and they do not
 * replace the rich SHANNON.AUDIT object.
 *
 * A separate terminal topic is prepared for the terminal-machine work.  The
 * publisher supplies the rich terminal observation object.  Retained current
 * observations can be replayed to a later subscriber without flattening them
 * into JSON or CSV.
 */

::class ShannonTopicBus public
::attribute manager get
::attribute topicFabric get

::method init
  expose manager topicFabric
  use arg managerArg
  manager = managerArg
  if manager == .nil then raise syntax 88.900 array('ShannonTopicBus requires an ObjectQueueManager')

  /* Observer queues.  A publication may fan out to more than one queue, but
     every delivered item remains an ordinary QueueWorkPackage. */
  ignored = self~must(manager~createQueue('SHANNON.EVENTS.ALL', 'TEMPORARY', 'OURLADYAIR.EVENTS', 250, 'shannon-admin'), 'create all-events queue')
  ignored = self~must(manager~createQueue('SHANNON.EVENTS.REVENUE', 'TEMPORARY', 'OURLADYAIR.EVENTS', 250, 'shannon-admin'), 'create revenue-events queue')
  ignored = self~must(manager~createQueue('SHANNON.EVENTS.SAFETY', 'TEMPORARY', 'OURLADYAIR.EVENTS', 250, 'shannon-admin'), 'create safety-events queue')
  ignored = self~must(manager~createQueue('SHANNON.TERMINAL.INBOX', 'TEMPORARY', 'OURLADYAIR.TERMINAL', 100, 'shannon-admin'), 'create terminal-observation queue')

  ignored = self~must(manager~grant('SHANNON.EVENTS.ALL', 'auditor', .QueueAccess~BROWSE, 'shannon-admin'), 'grant all-events browse')
  ignored = self~must(manager~grant('SHANNON.EVENTS.ALL', 'auditor', .QueueAccess~GET, 'shannon-admin'), 'grant all-events get')
  ignored = self~must(manager~grant('SHANNON.EVENTS.REVENUE', 'revenue-monitor', .QueueAccess~BROWSE, 'shannon-admin'), 'grant revenue browse')
  ignored = self~must(manager~grant('SHANNON.EVENTS.REVENUE', 'revenue-monitor', .QueueAccess~GET, 'shannon-admin'), 'grant revenue get')
  ignored = self~must(manager~grant('SHANNON.EVENTS.SAFETY', 'safety-monitor', .QueueAccess~BROWSE, 'shannon-admin'), 'grant safety browse')
  ignored = self~must(manager~grant('SHANNON.EVENTS.SAFETY', 'safety-monitor', .QueueAccess~GET, 'shannon-admin'), 'grant safety get')
  ignored = self~must(manager~grant('SHANNON.TERMINAL.INBOX', 'shannon-worker', .QueueAccess~BROWSE, 'shannon-admin'), 'grant terminal browse')
  ignored = self~must(manager~grant('SHANNON.TERMINAL.INBOX', 'shannon-worker', .QueueAccess~GET, 'shannon-admin'), 'grant terminal get')

  topicFabric = .QueueTopicFabric~new(manager, 'shannon-admin')

  ignored = self~must(topicFabric~defineTopic('SHANNON.EVENTS', 'ourladyair/shannon', 'TEMPORARY', 'OURLADYAIR.EVENTS', 'shannon-admin'), 'define Shannon event topic')
  ignored = self~must(topicFabric~grantTopicAccess('SHANNON.EVENTS', 'shannon-worker', .QueueTopicAccess~PUBLISH, 'shannon-admin'), 'grant Shannon event publish')
  ignored = self~must(topicFabric~grantTopicAccess('SHANNON.EVENTS', 'auditor', .QueueTopicAccess~BROWSE, 'shannon-admin'), 'grant Shannon event browse')
  ignored = self~must(topicFabric~subscribe('SHANNON.EVENTS.ALL', 'SHANNON.EVENTS', '#', 'SHANNON.EVENTS.ALL', 'TEMPORARY', 'shannon-admin'), 'subscribe all Shannon events')
  ignored = self~must(topicFabric~subscribe('SHANNON.EVENTS.REVENUE', 'SHANNON.EVENTS', 'revenue/+', 'SHANNON.EVENTS.REVENUE', 'TEMPORARY', 'shannon-admin'), 'subscribe revenue events')
  ignored = self~must(topicFabric~subscribe('SHANNON.EVENTS.SAFETY', 'SHANNON.EVENTS', 'safety/#', 'SHANNON.EVENTS.SAFETY', 'TEMPORARY', 'shannon-admin'), 'subscribe safety events')

  ignored = self~must(topicFabric~defineTopic('SHANNON.TERMINAL', 'ourladyair/terminal', 'TEMPORARY', 'OURLADYAIR.TERMINAL', 'shannon-admin'), 'define terminal observation topic')
  ignored = self~must(topicFabric~grantTopicAccess('SHANNON.TERMINAL', 'terminal-worker', .QueueTopicAccess~PUBLISH, 'shannon-admin'), 'grant terminal publish')
  ignored = self~must(topicFabric~grantTopicAccess('SHANNON.TERMINAL', 'auditor', .QueueTopicAccess~BROWSE, 'shannon-admin'), 'grant terminal browse')
  ignored = self~must(topicFabric~subscribe('SHANNON.TERMINAL.CURRENT', 'SHANNON.TERMINAL', '#', 'SHANNON.TERMINAL.INBOX', 'TEMPORARY', 'shannon-admin'), 'subscribe terminal observations')

::method publishGovernedTurn
  expose topicFabric
  use arg audit
  if audit == .nil then return .QueueOperationResult~failure('SHANNON_EVENT_AUDIT_REQUIRED')

  event = .directory~new
  event['schema'] = 'ourladyair.shannon.event.v1'
  event['kind'] = 'GOVERNED_TURN'
  event['audit'] = audit
  if audit~hasIndex('sessionId') then event['sessionId'] = audit['sessionId']
  if audit~hasIndex('turn') then event['turn'] = audit['turn']

  options = .table~new
  options['subtopic'] = 'turn/governed'
  options['correlationId'] = self~correlationFor(audit)
  governedOperation = topicFabric~publish('SHANNON.EVENTS', event, options, 'shannon-worker')
  if \governedOperation~ok then return governedOperation

  salesAllowed = .false
  if audit~hasIndex('governance') then do
    governance = audit['governance']
    if governance \== .nil then do
      if governance~hasIndex('salesAllowed') then salesAllowed = governance['salesAllowed']
    end
  end

  classEvent = .directory~new
  classEvent['schema'] = 'ourladyair.shannon.event.v1'
  classEvent['kind'] = 'TURN_CLASSIFICATION'
  classEvent['audit'] = audit
  if salesAllowed then classSubtopic = 'revenue/permitted'
  else classSubtopic = 'safety/suppressed'
  classEvent['classification'] = classSubtopic
  classOptions = .table~new
  classOptions['subtopic'] = classSubtopic
  classOptions['correlationId'] = self~correlationFor(audit)
  classOperation = topicFabric~publish('SHANNON.EVENTS', classEvent, classOptions, 'shannon-worker')
  if \classOperation~ok then return classOperation

  receipts = .directory~new
  receipts['governed'] = governedOperation~value
  receipts['classified'] = classOperation~value
  receipts['classification'] = classSubtopic
  return .QueueOperationResult~success(receipts)

::method publishTerminalObservation
  expose topicFabric
  use arg sourceSystem, sessionId, generation, observation, retainFlag = .true
  sourceSystem = sourceSystem~string
  sessionId = sessionId~string
  generation = generation~string
  segmentCheck = self~validSegment(sourceSystem)
  if \segmentCheck~ok then return segmentCheck
  segmentCheck = self~validSegment(sessionId)
  if \segmentCheck~ok then return segmentCheck

  event = .directory~new
  event['schema'] = 'ourladyair.terminal.observation.v1'
  event['sourceSystem'] = sourceSystem
  event['sessionId'] = sessionId
  event['generation'] = generation
  event['observation'] = observation

  options = .table~new
  options['subtopic'] = 'current/' || sourceSystem || '/' || sessionId
  options['correlationId'] = sourceSystem || ':' || sessionId || ':' || generation
  options['retain'] = retainFlag
  return topicFabric~publish('SHANNON.TERMINAL', event, options, 'terminal-worker')

::method receiveTerminalObservation
  expose manager
  return manager~get('SHANNON.TERMINAL.INBOX', 'shannon-worker')

::method correlationFor private
  use arg audit
  sessionPart = 'UNKNOWN'
  turnPart = '0'
  if audit~hasIndex('sessionId') then sessionPart = audit['sessionId']~string
  if audit~hasIndex('turn') then turnPart = audit['turn']~string
  return sessionPart || ':' || turnPart

::method validSegment private
  use arg text
  if text = '' then return .QueueOperationResult~failure('INVALID_TERMINAL_TOPIC_SEGMENT', 'empty')
  if text~pos('/') > 0 | text~pos('+') > 0 | text~pos('#') > 0 then return .QueueOperationResult~failure('INVALID_TERMINAL_TOPIC_SEGMENT', text)
  return .QueueOperationResult~success(text)

::method must private
  use arg operationResult, label
  if \operationResult~ok then raise syntax 88.900 array(label || ': ' || operationResult~code || ' ' || operationResult~detail)
  return operationResult

::requires 'ObjectQueueTopics.cls'
