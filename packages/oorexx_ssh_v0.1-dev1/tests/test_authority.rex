r=.SshEndpointRegistry~new
h=.TestHandler~new
r~registerSubsystem('sftp',h)
a=.SshEndpointAuthority~new
a~allowEndpoint('alice','SUBSYSTEM','sftp')
s=.SshServer~new(.nil,r,a)
d=s~resolve('alice',.SshEndpointRequest~new('SUBSYSTEM','sftp'))
call assert d~allowed,'alice permitted'
d=s~resolve('bob',.SshEndpointRequest~new('SUBSYSTEM','sftp'))
call assert \d~allowed,'bob denied'
say 'PASS test_authority'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::class TestHandler
::requires '../src/SshCore.cls'
