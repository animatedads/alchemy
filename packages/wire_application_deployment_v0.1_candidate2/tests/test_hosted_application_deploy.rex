topic=.Object~new
server=.WireUIServer~new(.nil,topic,'admin')
a=.HostedAppProbe~new('sample','ap-one')
b=.HostedAppProbe~new('sample','ap-one')
c=.HostedAppProbe~new('sample','ap-two')
call check server~publishHostedApplication(a,'sha-1')~ok,'initial installation'
call check (\server~publishHostedApplication(b,'sha-2','wrong')~ok),'reject stale CAS'
call check (\server~publishHostedApplication(c,'sha-2','sha-1')~ok),'reject access point change'
call check server~publishHostedApplication(b,'sha-2','sha-1')~ok,'upgraded generation'
call check server~hostedApplication('sample')==b,'current app object'
call check server~retiredHostedApplication('sample','sha-1')==a,'retained drain generation'
call check (\server~retireHostedApplication('sample','sha-1')~ok),'reject stale retirement'
call check server~retireHostedApplication('sample','sha-2')~ok,'retire live app'
call check server~hostedGeneration('sample')='','generation cleared'
server~registerApplication(a)
call check (\server~publishHostedApplication(b,'sha-3')~ok),'do not replace unowned app'
say 'PASS hosted application deployment'
exit 0
check: procedure
  use strict arg condition,label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  say 'PASS' label
  return
::class HostedAppProbe
::attribute applicationId get
::attribute accessPointId get
::method init
  expose applicationId accessPointId
  use strict arg applicationId,accessPointId
::requires 'WireUIServer.cls'
