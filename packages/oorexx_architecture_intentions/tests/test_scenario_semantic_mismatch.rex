/* Counterfactual binding cannot silently reinterpret a notification as queue. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('mismatch','Mismatch')
p~links~link('changed','a','b','core','EVENT','owner','Event')
p~links~bind('changed','direct_call','Local source','owner')
p~links~serviceIntent('changed','changed','NOTIFY','IMMEDIATE','b','owner','Notify')
s = .ArchitectureScenario~new('queue','Queue alternative','Try queue','owner')
s~bind('changed','queue_fabric','Different model, not yet approved')
e = .ArchitectureScenarioComparison~new(planner)
e~register(s)
result = e~compare(p)
if result['scenarios'][1]['state'] \== 'INCONSISTENT' then exit 1
found = .false
do issue over result['scenarios'][1]['plan']['issues']
  if issue['code'] == 'ARCH_CONNECT_SEMANTIC_MISMATCH' then found = .true
end
if \found then exit 1
say 'PASS incompatible queue-vs-notification semantics blocked'
::requires 'ArchitectureScenarios.cls'
