r=.SshEndpointRegistry~new
f=.BackendFactory~new
h=.SftpSubsystemHandler~new(f)
r~registerSubsystem('sftp',h)
d=r~resolve(.SshEndpointRequest~new('SUBSYSTEM','sftp'))
call assert d~allowed,'sftp registered in SSH registry'
e=d~handler~endpoint
call assert e~isA(.SftpEndpoint),'handler produces Rexx endpoint'
d=r~resolve(.SshEndpointRequest~new('SHELL'))
call assert \d~allowed,'shell still denied'
say 'PASS test_registry_integration'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::class BackendFactory
::method newBackend
  return .SftpMemoryBackend~new
::requires 'TestSupport.cls'
