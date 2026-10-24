/* Use real ConnectSelector dev2 read-only preflight with strict scoped grants. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
policy = .ConnectRoutePolicy~new
policy~allow('cat.lookup','request','DIRECT','LOCAL')
selector = .ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(.NoExecutionCall~new, -
  'DIRECT','LOCAL'),'LOCAL')
p = planner~project('dev2-policy','Strict ConnectSelector route policy')
p~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(selector)
p~links~link('lookup','front-end','catalogue','core','REQUEST_REPLY', -
  'architect','Read local record')
p~links~bind('lookup','direct_call','selected local invocation','architect')
p~links~placement('lookup','SAME_PROCESS','architect','deployment://local')
p~links~serviceIntent('lookup','cat.lookup','REQUEST','IMMEDIATE','LOCAL', -
  'architect','Read-only request')
plan = planner~plan(p)
call assert reviewed(plan,'lookup','DIRECT','ELIGIBLE_REGISTERED'), -
  'explicit grant admits registered DirectCall'
/* A named destination must not inherit the default route. */
p~links~serviceIntent('lookup','cat.lookup','REQUEST','IMMEDIATE','UNBOUND', -
  'architect','A new unbound target is a different security domain')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_CONNECT_SELECTOR_UNAVAILABLE'), -
  'unbound destination is rejected without executing'
/* A strict policy is default-deny even if an adapter exists. */
policy2 = .ConnectRoutePolicy~new
other = .ConnectSelector~new(policy2)
other~register('DIRECT',.ConnectCallAdapter~new(.NoExecutionCall~new, -
  'DIRECT','LOCAL'),'LOCAL')
p~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(other)
p~links~serviceIntent('lookup','cat.lookup','REQUEST','IMMEDIATE','LOCAL', -
  'architect','Revisit rejected grant')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_CONNECT_SELECTOR_UNAVAILABLE'), -
  'registered connector with no policy grant is rejected'
say 'PASS ConnectSelector dev2 strict route grants, destination isolation and default deny'
exit 0
assert:
  use arg cond, words
  if cond then return
  say 'FAIL:' words
  exit 1
hasIssue:
  use arg plan, code
  do item over plan['issues']
    if item['code'] == code then return .true
  end
  return .false
reviewed:
  use arg plan, id, provider, state
  do row over plan['connectSelectorReviews']
    if row['edgeId'] == id & row['provider'] == provider & row['status'] == state then -
      return .true
  end
  return .false
::class NoExecutionCall
::method request
  raise syntax 93.900 array('ARCH_TEST_INVOKED_PROVIDER')
::method notify
  raise syntax 93.900 array('ARCH_TEST_INVOKED_PROVIDER')
::requires 'ArchitecturePlanner.cls'
::requires 'ArchitectureConnectSelectorAdapter.cls'
