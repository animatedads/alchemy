address=.SocketAddresses~norm('239.255.42.50',47050,'lo','',1,'descriptor.contract')
listenerRaw=.FakeReadyListener~new(address)
listener=.ProviderSocketListener~new(listenerRaw,address)
if listener~descriptor<>77 then call fail 'listener descriptor'
if \listener~waitReady(25) then call fail 'listener readiness'
accepted=listener~tryAccept
if accepted=.nil then call fail 'tryAccept nil'
if accepted~recv(16)<>'ready' then call fail 'tryAccept payload'
sender=.ProviderSocketConnection~new(.FakeDrainedSocket~new,address)
if sender~descriptor<>88 then call fail 'sender descriptor'
if \sender~waitDrained(25) then call fail 'sender drain'
say 'PASS provider-neutral descriptor/readiness contract'
exit 0
fail: procedure
 parse arg why
 say 'FAIL' why
 exit 1
::class FakeReadyListener
::method init
 expose address
 use strict arg address
::method descriptor
 return 77
::method waitReady
 use strict arg timeout
 return timeout>=0
::method tryAccept
 return .FakeAccepted~new
::method accept
 return .FakeAccepted~new
::method close
 return 0
::class FakeAccepted
::method recv
 use strict arg maximum
 return 'ready'
::method send
 use strict arg bytes
 return length(bytes)
::method close
 return 0
::class FakeDrainedSocket
::method descriptor
 return 88
::method waitDrained
 use strict arg timeout
 return timeout>=0
::method send
 use strict arg bytes
 return length(bytes)
::method recv
 use strict arg maximum
 return .nil
::method close
 return 0
::requires 'SocketProvider.cls'
