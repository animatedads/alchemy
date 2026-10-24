/* Demonstrate four independently modelled links with ConnectSelector dev1.
 * Inject mock eligibility adapters: this example does not execute a service.
 */
parse arg outputPath
if outputPath == '' then outputPath = 'architecture-selector-example.json'
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-connector-example','I Love Cats: local, RPC, jobs, JMS')
p~domain~statement('A cats catalog with a portal, background processing and partner ERP','customer','meeting://2026-10-08')
selector = .ConnectSelector~new
selector~register('DIRECT',.EligibilityExample~new('DIRECT'))
selector~register('RPC',.EligibilityExample~new('RPC'))
selector~register('QUEUE',.EligibilityExample~new('QUEUE'))
p~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(selector)

p~links~link('local','app','local-service','core','REQUEST_REPLY','architect','Local lookup')
p~links~bind('local','direct_call','same-process call','architect')
p~links~placement('local','SAME_PROCESS','architect','layout://app-v1')
p~links~serviceIntent('local','cat.local.lookup','REQUEST','IMMEDIATE','','architect','Need direct result')

p~links~link('public','portal','remote-catalogue','public','REQUEST_REPLY','architect','Distributed API')
p~links~bind('public','json_rpc','JSON-RPC contract','customer')
p~links~placement('public','REMOTE','architect','layout://api-v1')
p~links~serviceIntent('public','cat.lookup','REQUEST','IMMEDIATE','catalogue','architect','Need RPC result')

p~links~link('index-job','api','indexer','background','COMMAND','architect','Durable indexing')
p~links~bind('index-job','queue_fabric','durable job acceptance','architect')
p~links~serviceIntent('index-job','cat.reindex','ENQUEUE','DURABLE','WORK','architect','Persist work request')

p~links~link('erp','billing','partner-erp','partner','EVENT','architect','Partner JMS bus')
p~links~bind('erp','jms','Partner requires JMS','customer')
p~links~jmsBridge('erp','QUEUE_TO_JMS','QUEUE.OUT','JMS.ERP','architect','Bridge to partner')

p~groundRules~addRule('external-no-direct','Security separation','2','SUBSYSTEM','public', -
  'DENY_BINDING','interconnect',.Array~of('direct_call'),'security','policy://2')

plan = planner~plan(p)
call lineout outputPath, .JSON~toJSON(plan)
call lineout outputPath
call stream outputPath,'C','CLOSE'
say 'State:' plan['state']
say 'Interconnect reviews:' plan['connectSelectorReviews']~items
say 'Policy alternatives:' plan['interconnectAlternatives']~items
say 'Unresolved integration requests:' plan['buildRequest']['externalIntegrationRequirements']~items
say 'Wrote:' outputPath
exit 0

::class EligibilityExample
::attribute family get
::method init
  expose family
  use strict arg family
::method supports
  use strict arg intent
  if self~family == 'QUEUE' then return intent~mode == 'ENQUEUE'
  return intent~mode == 'REQUEST' | intent~mode == 'NOTIFY'
::method execute
  raise syntax 93.900 array('EXAMPLE_MUST_NEVER_EXECUTE')
::requires 'ArchitecturePlanner.cls'
::requires 'ArchitectureConnectSelectorAdapter.cls'
