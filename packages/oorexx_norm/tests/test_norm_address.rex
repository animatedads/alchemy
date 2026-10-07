parse source . . here
root=filespec('location',here)||'..'
call directory root
addr=.SocketAddresses~norm('239.255.42.1',47001,'lo','',42,'norm.qual')
if addr~transport<>.SocketTransportKind~NORM then call fail 'transport'
if addr~scheme<>.SocketScheme~NORM then call fail 'scheme'
if addr~addressFamily<>.SocketAddressFamily~NORM then call fail 'family'
if \addr~multicast then call fail 'multicast capability'
if addr~normGroup<>'239.255.42.1' then call fail 'group'
if addr~normInterface<>'lo' then call fail 'interface'
if addr~normNodeId<>42 then call fail 'node id'
if \addr~family~capabilities~multicast then call fail 'family multicast'
say 'PASS NORM SocketAddress contract'
exit 0
fail: procedure
  parse arg why
  say 'FAIL' why
  exit 1
::requires 'SocketProvider.cls'
