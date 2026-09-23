r=.SshEndpointRegistry~new
h=.TestHandler~new('sftp')
r~registerSubsystem('sftp',h)
d=r~resolve(.SshEndpointRequest~new('SUBSYSTEM','sftp'))
call assert d~allowed,'registered subsystem resolves'
call assert d~handler==h,'registered handler retained'
d=r~resolve(.SshEndpointRequest~new('SUBSYSTEM','shell'))
call assert \d~allowed,'unknown subsystem denied'
d=r~resolve(.SshEndpointRequest~new('SHELL'))
call assert \d~allowed,'shell denied by default'
r~registerExec('queue-submit',.TestHandler~new('queue'))
d=r~resolve(.SshEndpointRequest~new('EXEC','queue-submit arg1 arg2'))
call assert d~allowed,'registered exec verb resolves'
d=r~resolve(.SshEndpointRequest~new('EXEC','rm -rf /'))
call assert \d~allowed,'arbitrary command denied'
say 'PASS test_registry'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::class TestHandler
::method init; expose _name; use strict arg _name
::method name; expose _name; return _name
::requires '../src/SshCore.cls'
