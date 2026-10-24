cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
engine = .ArchitecturePlanner~new(cat)
p = engine~project('spot','Policy qualification')
p~answer('deployment_model','cloud','Cloud','author')
p~answer('cloud_purchase','spot','Interruptible compute','author')
p~answer('workload','service','Interactive','author')
plan = engine~plan(p)
found = 0
do issue over plan['issues']
  if issue['code'] == 'ARCH_SPOT_RECOVERY' then found = 1
end
if found == 0 | plan['state'] \== 'INCONSISTENT' then do
  say 'FAIL unsafe spot service not blocked'
  exit 1
end
p~answer('workload','batch','Safe to retry (intent only)','author')
plan = engine~plan(p)
do issue over plan['issues']
  if issue['code'] == 'ARCH_SPOT_RECOVERY' then do
    say 'FAIL safe-to-retry branch not reopened'
    exit 1
  end
end
say 'PASS interruptible workload qualification rule'
::requires 'ArchitecturePlanner.cls'
