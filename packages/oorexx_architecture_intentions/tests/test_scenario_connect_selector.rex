/* Real selector explain() across independently projected scenario variants. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
sel = .ConnectSelector~new
sel~register('DIRECT',.ConnectCallAdapter~new(.UncallableService~new,'DIRECT'))
sel~register('RPC',.ConnectCallAdapter~new(.UncallableService~new,'RPC'))
p = planner~project('selector-scenarios','Independent connector alternatives')
p~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(sel)
p~links~link('lookup','ui','catalog','core','REQUEST_REPLY','owner','Lookup a cat')
p~links~bind('lookup','direct_call','Local function','owner')
p~links~placement('lookup','SAME_PROCESS','owner','Diagram of local deployment')
p~links~serviceIntent('lookup','cat.lookup','REQUEST','IMMEDIATE','','owner','Get a result')
local = .ArchitectureScenario~new('local','Local','In-process','owner')
remote = .ArchitectureScenario~new('remote','Remote','RPC required','owner')
remote~choose('deployment_model','cloud','Distributed service')
remote~bind('lookup','json_rpc','Remote invocation')
remote~place('lookup','REMOTE','Cloud service topology')
e = .ArchitectureScenarioComparison~new(planner)
e~register(local)
e~register(remote)
result = e~compare(p)
if result['interconnectMatrix'][1]['qualificationByScenario']['local'] \== 'ELIGIBLE_REGISTERED' then exit 1
if result['interconnectMatrix'][1]['qualificationByScenario']['remote'] \== 'ELIGIBLE_REGISTERED' then exit 1
if p~links~links['lookup']['binding'] \== 'direct_call' then exit 1
say 'PASS scenario-qualified real ConnectSelector explain() without execution'
exit 0
::class UncallableService
::method request
  raise syntax 93.900 array('UNEXPECTED_CONNECTOR_EXECUTION')
::method notify
  raise syntax 93.900 array('UNEXPECTED_CONNECTOR_EXECUTION')
::requires 'ArchitectureScenarios.cls'
::requires 'ArchitectureConnectSelectorAdapter.cls'
