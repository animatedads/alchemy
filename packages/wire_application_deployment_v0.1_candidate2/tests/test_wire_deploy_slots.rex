slots=.WireDeploymentGatewaySlots~new
one=.StubBinding~new('one')
two=.StubBinding~new('two')
call check slots~publish('sample','r1',one),'first bind'
call check \slots~publish('sample','r2',two,'wrong'),'CAS rejects wrong expected'
call check slots~publish('sample','r2',two,'r1'),'new binding'
call check slots~browserBootstrap('sample','wss://example.test')['name']='two','browser sees current generation'
call check slots~generation('sample')='r2','generation readable'
call check \slots~retire('sample','r1'),'stale retirement denied'
call check slots~retire('sample','r2'),'retire succeeds'
say 'PASS gateway deployment slots'
exit 0
check: procedure
  use strict arg predicate,message
  if \predicate then do
    say 'FAIL' message
    exit 1
  end
  say 'PASS' message
  return
::class StubBinding
::method init
  expose name
  use strict arg name
::method provision
  return .true
::method browserBootstrap
  expose name
  d=.directory~new
  d['name']=name
  return d
::requires 'WireDeploymentGatewaySlots.cls'
