/* JMS bridge is qualified as an external integration, not native ConnectSelector. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('interop','Event exchange')
p~links~link('erp','app','erp','legacy','EVENT','customer','ERP bridge')
p~groundRules~addRule('approved','Customer approved links','1', -
  'PROJECT','interop','ALLOW_BINDING','interconnect', -
  .Array~of('jms'),'customer','contract://jms')
scenario = .ArchitectureScenario~new('jms-edge','JMS enterprise','Legacy broker','customer')
scenario~bind('erp','jms','Mandated external broker','contract://jms')
scenario~bridge('erp','QUEUE_TO_JMS','internal-queue','broker-A','Outgoing enterprise event')
e = .ArchitectureScenarioComparison~new(planner)
e~register(scenario)
result = e~compare(p)
plan = result['scenarios'][1]['plan']
if plan['interconnects']['edges'][1]['jmsBridge']['direction'] \== 'QUEUE_TO_JMS' then exit 1
if plan['buildRequest']['externalIntegrationRequirements']~items \== 1 then exit 1
if plan['connectSelectorReviews'][1]['provider'] \== 'JMS_BRIDGE_NOT_CONNECT_SELECTOR_PROVIDER' then exit 1
if p~links~links['erp']['binding'] \== '' then exit 1
say 'PASS isolated JMS bridge scenario with explicit direction and unresolved qualification'
::requires 'ArchitectureScenarios.cls'
