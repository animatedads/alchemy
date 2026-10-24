/* Three proposals from one business description. Each is a design candidate,
 * NOT an auto-approved implementation or deployment action.
 * Run in package root: rexx examples/compare_cats_scenarios.rex [output.json]
 */
parse arg output
if output == '' then output = 'cats-scenarios.json'
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-platform','I Love Cats')
p~domain~statement('We want an I Love Cats business platform','business sponsor','first meeting')
p~domain~entity('cat','SUBJECT','Cat','business sponsor')
p~domain~entity('legacy','SYSTEM','Legacy records (unverified)','business sponsor','','EXISTING')
p~includeScope('CUSTOMER','cats-inc')
p~groundRules~addRule('customer-policy','Integration standard','draft-1', -
  'CUSTOMER','cats-inc','ALLOW_BINDING','interconnect', -
  .Array~of('direct_call','json_rpc','queue_fabric'), -
  'customer architect','policy://customer/draft')
p~groundRules~addRule('spiral1','SPIRAL 1','pending-control-inventory', -
  'CUSTOMER','cats-inc','CONTROL','SPIRAL_1_CONTROL_INVENTORY',.Array~new, -
  'compliance owner','customer://controls/pending')
p~links~link('cat-status','catalog','cat-status-handler','core','EVENT', -
  'architect','Cat record change notification')
engine = .ArchitectureScenarioComparison~new(planner)
local = .ArchitectureScenario~new('local','Local pilot', -
  'Single process until distributed requirements are proven','architect')
local~choose('deployment_model','local','Local development pilot')
local~choose('frontend','cli','Prototype user experience')
local~choose('storage','filesystem','Legacy migration unresolved')
local~bind('cat-status','direct_call','Same-process event callback')
local~place('cat-status','SAME_PROCESS','Local process design; unqualified')
local~intent('cat-status','catChanged','NOTIFY','IMMEDIATE','cat-status-handler', -
  'Synchronous notification without delivery guarantee')
engine~register(local)
cloud = .ArchitectureScenario~new('cloud','Distributed service','Service-node deployment','architect')
cloud~choose('deployment_model','cloud','Remote service')
cloud~choose('frontend','web','Customer web presence')
cloud~choose('interconnect','api','JSON-RPC integration')
cloud~choose('storage','object','Evaluate object persistence')
cloud~bind('cat-status','json_rpc','Remote synchronous message notification')
cloud~place('cat-status','REMOTE','Service-node separation')
cloud~intent('cat-status','catChanged','NOTIFY','BEST_EFFORT','cat-status-api', -
  'Remote notification needs transport/auth qualification')
engine~register(cloud)
grid = .ArchitectureScenario~new('rexxos','RexxOS MU/MI','Grid-based service placement','architect')
grid~choose('deployment_model','rexxos_mu_mi','Grid deployment candidate')
grid~choose('deployment_target','rexxos','Required grid target')
grid~choose('xtp_carrier','l2','Candidate L2 fabric')
grid~choose('network_scope','same_l2','Subject to site qualification')
grid~choose('storage','fabric','Evaluate Storage Fabric')
grid~bind('cat-status','queue_fabric','Durable distributed event')
grid~place('cat-status','REMOTE','Grid worker placement')
grid~intent('cat-status','catChanged','ENQUEUE','DURABLE','cat-events', -
  'Queue acceptance is not synchronous completion')
engine~register(grid)
comparison = engine~compare(p)
call lineout output,.JSON~toJSON(comparison)
call lineout output
call stream output,'C','CLOSE'
say 'Wrote non-executable comparison:' output
say 'Scenarios:' comparison['scenarioCount']
do proposal over comparison['scenarios']
  say proposal['id']': 'proposal['state'] -
    'questions='proposal['openQuestionCount'] -
    'runtime components='proposal['plan']['buildRequest']['requirements']~items
end
say 'No winner: insufficient business, compliance, price and target evidence'
::requires 'ArchitectureScenarios.cls'
