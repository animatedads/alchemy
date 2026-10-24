cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
cat~componentAt('socket_provider')['requires']~append('xtp')
planner = .ArchitecturePlanner~new(cat)
project = planner~project('cycle','Cycle detection')
project~answer('deployment_model','rexxos_mu_mi','test','tester')
plan = planner~plan(project)
found = .false
do issue over plan['issues']
  if issue['code'] == 'ARCH_DEP_CYCLE' then found = .true
end
if \found then do
  say 'FAIL dependency cycle omitted'
  exit 1
end
if plan['state'] \== 'INCONSISTENT' then do
  say 'FAIL dependency cycle not blocked'
  exit 1
end
say 'PASS dependency cycle detected and blocked'
::requires 'ArchitecturePlanner.cls'
