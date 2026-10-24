/* Three isolated architecture candidates, same scoped business and policies. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-scenarios','I Love Cats')
p~domain~statement('We operate a cat-care catalogue','product owner','discovery workshop')
p~domain~clarify('BUSINESS_OUTCOME','Owner directory and cat records','product owner')
p~includeScope('CUSTOMER','cats-ltd')
p~feature('records','Cat record maintenance','MUST','CRUD acceptance checks','customer')
p~answer('deployment_model','local','Baseline local pilot','architect')
p~answer('deployment_target','linux','Linux workstation pilot','architect')
p~answer('storage','filesystem','Existing files pilot','architect')
p~links~link('cat-event','application','event-receiver','core','EVENT', -
  'architect','Changes are published to registered consumers')
p~links~bind('cat-event','direct_call','Single-process proof of concept','architect')
p~links~placement('cat-event','SAME_PROCESS','architect','Pilot design diagram')
p~links~serviceIntent('cat-event','catChanged','NOTIFY','IMMEDIATE','event-receiver', -
  'architect','Events remain independent of connection technology')
do guarantee over .Array~of('AUTH','DELIVERY','RECOVERY')
  p~links~guarantee('cat-event',guarantee,'Pilot contractual design','architect','test://pilot')
end
p~groundRules~addRule('customer-bounds','Customer interconnect policy','1', -
  'CUSTOMER','cats-ltd','ALLOW_BINDING','interconnect', -
  .Array~of('direct_call','json_rpc','queue_fabric'),'security owner','policy://customer/1')
baseBefore = planner~plan(p)
compareEngine = .ArchitectureScenarioComparison~new(planner)
local = .ArchitectureScenario~new('local','Small pilot','No distributed requirement','architect')
local~choose('frontend','cli','Staff pilot','spec://staff')
local~choose('interconnect','none','No general cross-host carrier','spec://pilot')
compareEngine~register(local)
cloud = .ArchitectureScenario~new('cloud','Cloud service','Remote customer request','architect')
cloud~choose('deployment_model','cloud','Use service nodes','customer://placement')
cloud~choose('deployment_target','linux','Linux cloud host','customer://target')
cloud~choose('frontend','headless','No browser yet','spec://frontend')
cloud~choose('storage','object','Remote object persistence','customer://storage')
cloud~choose('interconnect','api','Externally routable link','customer://rpc')
cloud~bind('cat-event','json_rpc','Remote integration','customer://rpc')
cloud~place('cat-event','REMOTE','Deployment topology witness')
cloud~price('compute',3,100,'GBP','Estimated service hours','quote://cloud-compute')
cloud~price('storage',10,2,'GBP','Estimated storage units','quote://cloud-storage')
compareEngine~register(cloud)
grid = .ArchitectureScenario~new('rexxos','RexxOS MU/MI','Grid workload qualification','architect')
grid~choose('deployment_model','rexxos_mu_mi','Grid variant','proposal://grid')
grid~choose('deployment_target','rexxos','Required MU/MI platform','proposal://grid')
grid~choose('xtp_carrier','l2','Candidate same L2 fabric','proposal://network')
grid~choose('network_scope','same_l2','Pilot L2 site','proposal://network')
grid~choose('storage','fabric','Distributed object storage','proposal://storage')
grid~bind('cat-event','queue_fabric','Durable status changes','architect')
grid~intent('cat-event','catChanged','ENQUEUE','DURABLE','cat-event-queue', -
  'Persist event until claimed; no synchronous completion assumption')
grid~place('cat-event','REMOTE','Queue consumer on separately deployed grid node')
grid~price('compute',15,10,'GBP','Grid host-hours estimate','quote://grid-compute')
grid~price('storage',2,15,'GBP','Grid fabric quota estimate','quote://grid-storage')
grid~price('fabric_operations',1,70,'GBP','Fabric operations estimate','quote://grid-operations')
compareEngine~register(grid)
comparison = compareEngine~compare(p)
call assert comparison['scenarioCount'] == 3,'three explicit scenarios'
call assert comparison['recommendation'] == .nil,'no invented winner'
call assert comparison['executable'] == .JSON~false,'comparison not executable'
call assert comparison['interconnectMatrix']~items == 1,'per-edge matrix'
links = comparison['interconnectMatrix'][1]
call assert links['bindingByScenario']['local'] == 'direct_call','direct local'
call assert links['bindingByScenario']['cloud'] == 'json_rpc','remote rpc'
call assert links['bindingByScenario']['rexxos'] == 'queue_fabric','queue grid'
call assert links['placementByScenario']['cloud'] == 'REMOTE','remote deployment'
call assert links['qualificationByScenario']['rexxos'] == 'SELECTOR_NOT_PROBED', -
  'unregistered selector is question, not fabricated qualification'
call assert comparison['costMatrix'][1]['status'] == 'NO_COST_DRIVERS_MODELED', -
  'local machine costs are not silently zero'
call assert comparison['costMatrix'][1]['estimatedMonthly'] == .nil, -
  'unmodeled costs are null'
call assert comparison['costMatrix'][2]['estimatedMonthly'] == 320, -
  'cloud estimate uses only supplied quote assumptions'
call assert comparison['costMatrix'][3]['estimatedMonthly'] == 250, -
  'grid estimate uses only supplied quote assumptions'
call assert p~quotes~items == 0,'project quotes untouched'
call assert p~value('deployment_model') == 'local','project deployment unchanged'
call assert p~links~links['cat-event']['binding'] == 'direct_call', -
  'project link not mutated by scenario alternatives'
call assert p~links~links['cat-event']['guarantees']~items == 3, -
  'original guarantees unaffected'
call assert comparison['scenarios'][2]['plan']['interconnects']['edges'][1]['guarantees']~items == 0, -
  'old direct-call guarantees cleared after RPC switch'
call assert comparison['scenarios'][3]['plan']['interconnects']['edges'][1]['serviceIntent']['mode'] == 'ENQUEUE', -
  'explicit queue enqueue intention retained'
call assert comparison['scenarios'][2]['plan']['buildRequest']['buildLock'] == .nil, -
  'cloud artifacts unresolved'
call assert comparison['scenarios'][3]['plan']['buildRequest']['buildLock'] == .nil, -
  'grid artifacts unresolved'
call assert baseBefore['effectiveAnswers']['deployment_model'] == 'local', -
  'baseline decision snapshot stable'
/* Ground rules copied and applied consistently; a forbidden variant must fail
 * only within its isolated scenario and must not poison the other variants. */
p~groundRules~addRule('exclude-grid','Customer platform limit','2', -
  'PROJECT','cats-scenarios','DENY_CHOICE','deployment_model', -
  .Array~of('rexxos_mu_mi'),'policy council','policy://project/2')
excluded = compareEngine~compare(p)
call assert excluded['scenarios'][3]['state'] == 'INCONSISTENT', -
  'grid blocked by customer ground rule'
call assert excluded['scenarios'][1]['state'] \== 'INCONSISTENT', -
  'local unaffected by grid restriction'
call assert excluded['scenarios'][2]['state'] \== 'INCONSISTENT', -
  'cloud unaffected by grid restriction'
if arg(1,'E') then do
  parse arg outputDirectory
  files = .ArchitectureScenarioWriter~new~write(comparison,outputDirectory)
  call assert files~items == 7,'comparison + three plans + three build requests'
  do file over files
    parsed = .JSON~fromJSON(charin(file,1,chars(file)))
    call stream file,'C','CLOSE'
    call assert parsed \== .nil,'valid JSON output'
  end
end
say 'PASS scenario comparison: isolated clones, links, policy, quote provenance, JSON exports'
exit 0
assert:
  use arg truth, reason
  if truth then return
  say 'FAIL:' reason
  exit 1
::requires 'ArchitectureScenarioWriter.cls'
