/* Architecture Intentions + real ConnectSelector 0.1 dev1 selection surface.
 * Mock connector supports() only; execute() must never be reached by planner.
 */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
sel = .ConnectSelector~new
sel~register('DIRECT',.ConnectCallAdapter~new(.NoExecutionCall~new,'DIRECT'))
sel~register('RPC',.ConnectCallAdapter~new(.NoExecutionCall~new,'RPC'))
manager = .QueueManagerProbe~new
manager~durableStore = .Object~new
sel~register('QUEUE',.ConnectQueueAdapter~new(manager,'WORK','producer'))
adapter = .ArchitectureConnectSelectorAdapter~new(sel)

/* A tiny local service must not drag Queue Fabric or a cluster into runtime. */
p = planner~project('cats-local','Cat catalogue on one machine')
p~connectSelectorAdapter = adapter
p~links~link('lookup','local-ui','catalogue','core','REQUEST_REPLY','architect','Read local cat record')
p~links~bind('lookup','direct_call','same-process domain API','architect')
p~links~placement('lookup','SAME_PROCESS','architect','deployment-plan://cats/local')
p~links~serviceIntent('lookup','cat.lookup','REQUEST','IMMEDIATE','','architect','Return cat object')
plan = planner~plan(p)
call require plan['connectSelectorReviews']~items == 1,'single read-only selector review'
call require plan['connectSelectorReviews'][1]['status'] == 'ELIGIBLE_REGISTERED','DIRECT registered and supported'
call require plan['connectSelectorReviews'][1]['provider'] == 'DIRECT','provider is DIRECT'
call require hasComponent(plan,'connect_selector'),'runtime selector requested'
call require \hasComponent(plan,'queue_fabric'),'minimal solution has no Queue Fabric'
call require plan['buildRequest']['externalIntegrationRequirements']~items == 0,'no invented external dependencies'
call require \hasQuestion(plan,'link_lookup_placement'),'same-process evidence recorded'

/* Distributed/heterogeneous interactions are independently composed. */
p~links~link('remote-api','web','catalogue','public','REQUEST_REPLY','architect','Public RPC call')
p~links~bind('remote-api','json_rpc','published API','customer')
p~links~placement('remote-api','REMOTE','architect','deployment-plan://cats/api')
p~links~serviceIntent('remote-api','cat.lookup','REQUEST','IMMEDIATE','catalog-api','architect','RPC result needed')
p~links~link('work','api','indexer','worker','COMMAND','architect','Persistent worker job')
p~links~bind('work','queue_fabric','durable work','architect')
p~links~serviceIntent('work','index.submit','ENQUEUE','DURABLE','WORK','architect','Accept durable job')
p~links~link('erp-event','billing','erp','finance','EVENT','architect','Customer JMS boundary')
p~links~bind('erp-event','jms','partner contract','customer')
p~links~jmsBridge('erp-event','QUEUE_TO_JMS','WORK','JMS.ERP','architect','Outbound ERP integration')
plan = planner~plan(p)
call require plan['connectSelectorReviews']~items == 4,'four edge reviews'
call require reviewed(plan,'remote-api','RPC','ELIGIBLE_REGISTERED'),'RPC provided'
call require reviewed(plan,'work','QUEUE','ELIGIBLE_REGISTERED'),'durable enqueue provided'
call require reviewed(plan,'erp-event','JMS_BRIDGE_NOT_CONNECT_SELECTOR_PROVIDER', -
  'JMS_BRIDGE_REQUIRES_EXTERNAL_QUALIFICATION'),'JMS not a selectable provider'
call require hasComponent(plan,'queue_fabric'),'durable job and JMS bridge require queue'
/* The REAL Queue adapter refuses durable admission with no durable store. */
manager~durableStore = .nil
plan = planner~plan(p)
call require hasIssue(plan,'ARCH_CONNECT_SELECTOR_UNAVAILABLE'),'durable queue without persistent store blocked'
call require reviewed(plan,'work','QUEUE','NOT_SUPPORTED_BY_REGISTERED_SELECTOR'), -
  'actual Queue adapter refuses unqualified durability'
manager~durableStore = .Object~new
plan = planner~plan(p)
call require reviewed(plan,'work','QUEUE','ELIGIBLE_REGISTERED'), -
  'restored store lets selector propose the configured route'
call require plan['buildRequest']['externalIntegrationRequirements']~items == 2, -
  'RPC and JMS integration still require qualification'
call require hasQuestion(plan,'link_erp-event_TRANSACTION'),'JMS transaction proof asked'
call require hasQuestion(plan,'link_erp-event_IDEMPOTENCY'),'JMS idempotency proof asked'
call require hasQuestion(plan,'link_erp-event_DEAD_LETTER'),'JMS DLQ semantics asked'

/* Actual selector refuses unavailable explicit provider; there is no fallback. */
empty = .ConnectSelector~new
p~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(empty)
plan = planner~plan(p)
call require hasIssue(plan,'ARCH_CONNECT_SELECTOR_UNAVAILABLE'),'unregistered connector explicit fail'
call require plan['state'] == 'INCONSISTENT','unregistered connector blocks architecture'
p~connectSelectorAdapter = adapter

/* A Queue Fabric put is not synchronous request/reply. */
p~links~link('bad','browser','worker','worker','REQUEST_REPLY','architect','Mis-modelled queue request')
p~links~bind('bad','queue_fabric','try queue instead of RPC','architect')
p~links~serviceIntent('bad','job.result','REQUEST','IMMEDIATE','WORK','architect','Need synchronous value')
plan = planner~plan(p)
call require hasIssue(plan,'ARCH_CONNECT_SEMANTIC_MISMATCH'),'queue cannot masquerade as completed RPC'

/* DirectCall is forbidden across process boundaries. */
p~links~link('illegal-direct','ui','remote','remote','REQUEST_REPLY','architect','Incorrect placement')
p~links~bind('illegal-direct','direct_call','attempt remote direct','architect')
p~links~placement('illegal-direct','REMOTE','architect','deployment-plan://remote')
p~links~serviceIntent('illegal-direct','remote.lookup','REQUEST','IMMEDIATE','','architect','Need answer')
plan = planner~plan(p)
call require hasIssue(plan,'ARCH_CONNECT_SEMANTIC_MISMATCH'),'DirectCall remote blocked'

/* A policy rejecting DirectCall cannot be overridden by runtime eligibility. */
p~groundRules~addRule('no-direct','Regulated customer boundary','1','LINK','lookup', -
  'DENY_BINDING','interconnect',.Array~of('direct_call'),'policy owner','policy://reviewed')
plan = planner~plan(p)
call require hasIssue(plan,'ARCH_POLICY_DENIED'),'selector eligibility is not policy permission'
call require optionExcluded(plan,'lookup','direct_call','no-direct'),'policy matrix cites denied candidate'
call require optionPermitted(plan,'lookup','json_rpc'),'policy permits alternative without claiming capability'
say 'PASS ConnectSelector real explain(): DIRECT/RPC/QUEUE, JMS bridge, locality, deny and mismatch'
exit 0
require:
  use strict arg condition, explanation
  if condition then return
  say 'FAIL:' explanation
  exit 1
hasComponent:
  use arg data, id
  do item over data['buildRequest']['requirements']
    if item['componentId'] == id then return .true
  end
  return .false
hasQuestion:
  use arg data, id
  do item over data['openQuestions']
    if item['id'] == id then return .true
  end
  return .false
hasIssue:
  use arg data, id
  do item over data['issues']
    if item['code'] == id then return .true
  end
  return .false
reviewed:
  use arg data, edge, provider, status
  do item over data['connectSelectorReviews']
    if item['edgeId'] == edge & item['provider'] == provider & item['status'] == status then return .true
  end
  return .false
optionExcluded:
  use arg data, edge, binding, ruleId
  do item over data['interconnectAlternatives']
    if item['edgeId'] \== edge | item['binding'] \== binding then iterate
    if item['status'] \== 'POLICY_EXCLUDED' then return .false
    do block over item['exclusionReasons']
      if block['ruleId'] == ruleId then return .true
    end
  end
  return .false
optionPermitted:
  use arg data, edge, binding
  do item over data['interconnectAlternatives']
    if item['edgeId'] == edge & item['binding'] == binding then -
      return item['status'] == 'POLICY_PERMITTED_NOT_QUALIFIED'
  end
  return .false
::class NoExecutionCall
::method request
  raise syntax 93.900 array('PLANNER_EXECUTED_REQUEST')
::method notify
  raise syntax 93.900 array('PLANNER_EXECUTED_NOTIFY')
::class QueueManagerProbe
::attribute durableStore
::method init
  expose durableStore
  durableStore = .nil
::method queue
  use strict arg name
  return .PermanentQueueProbe~new
::method put
  raise syntax 93.900 array('PLANNER_EXECUTED_QUEUE_PUT')
::class PermanentQueueProbe
::method lifecycle
  return 'PERMANENT'
::requires 'ArchitecturePlanner.cls'
::requires 'ArchitectureConnectSelectorAdapter.cls'
