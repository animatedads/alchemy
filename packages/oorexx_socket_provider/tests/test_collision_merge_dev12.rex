call main
exit 0

main:
  call assert .SocketProviderBuild~VERSION='0.1-dev13','dev13 build version'

  /* UDP branch survived, including ephemeral listener port 0. */
  udpOld=.SocketAddresses~udp('127.0.0.1',47001,'udp.old.signature')
  call assert udpOld~transport=.SocketTransportKind~UDP,'UDP transport retained'
  call assert udpOld~logicalName='udp.old.signature','dev10-A UDP signature retained'
  udpNew=.SocketAddresses~udp('127.0.0.1',0,.false,'udp.new.signature')
  call assert udpNew~port=0,'dev10-B ephemeral UDP port retained'
  call assert udpNew~logicalName='udp.new.signature','dev10-B UDP signature retained'

  groupOld=.SocketAddresses~ipMulticast('239.255.42.60',47060,'mcast.old.signature')
  call assert groupOld~logicalName='mcast.old.signature','dev10-A multicast signature retained'
  groupNew=.SocketAddresses~ipMulticast('239.255.42.61',47061,'eth7','198.51.100.61','mcast.new.signature')
  call assert groupNew~metadata['interface']='eth7','dev10-B multicast interface retained'
  call assert groupNew~metadata['source']='198.51.100.61','dev10-B multicast source retained'

  /* Historical capability truth survives while the current broad XTP family
   * now reflects qualified dev17 multicast. */
  call assert .SocketFamilies~xtp~capabilities~multicast,'XTP current family multicast is true' 
  call assert \.SocketCapabilityProfiles~xtpDev14Rexx~multicast,'XTP dev14 multicast remains false'

  /* Descriptor/readiness branch survived. */
  address=.SocketAddresses~norm('239.255.42.62',47062,'lo','',1,'descriptor.merge')
  listener=.ProviderSocketListener~new(.FakeReadyListener~new,address)
  call assert listener~descriptor=77,'listener descriptor retained'
  call assert listener~waitReady(25),'listener waitReady retained'
  accepted=listener~tryAccept
  call assert accepted<>.nil,'listener tryAccept retained'
  call assert accepted~recv(16)='ready','accepted payload retained'
  sender=.ProviderSocketConnection~new(.FakeDrainedSocket~new,address)
  call assert sender~descriptor=88,'sender descriptor retained'
  call assert sender~waitDrained(25),'sender waitDrained retained'

  /* Generic multicast binding remains available beside concrete RxSock UDP. */
  backend=.FakeUdpBackend~new
  binding=.RexxUdpSocketBinding~new(backend)
  call assert binding<>.nil,'generic UDP/multicast binding retained'

  say 'PASS Socket Provider dev13 collision merge retained with current XTP dev17 truth'
  return

assert: procedure
  use strict arg ok, why
  if \ok then do
    say 'FAIL' why
    exit 1
  end
  return

::class FakeReadyListener
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

::class FakeUdpBackend
::method listener
  use strict arg address, backlog=32
  return .nil
::method sender
  use strict arg address
  return .nil
::method join
  use strict arg address, request
  return .nil
::method listenerOn
  use strict arg membership, address, backlog=32
  return .nil

::requires '../src/SocketProvider.cls'
::requires '../src/SocketIntentions.cls'
