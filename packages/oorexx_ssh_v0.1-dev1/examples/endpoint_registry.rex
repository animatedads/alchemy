registry=.SshEndpointRegistry~new
registry~registerSubsystem('sftp',.ExampleHandler~new)
server=.SshServer~new(.nil,registry,.SshAllowAllAuthority~new)
d=server~resolve('demo-user',.SshEndpointRequest~new('SUBSYSTEM','sftp'))
say 'sftp allowed:' d~allowed
say 'shell allowed:' server~resolve('demo-user',.SshEndpointRequest~new('SHELL'))~allowed
exit 0
::class ExampleHandler
::requires '../src/SshCore.cls'
