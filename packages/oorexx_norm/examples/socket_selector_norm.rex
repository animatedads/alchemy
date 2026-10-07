/* Same SocketProvider acquisition shape as other transports. */
a=.SocketAddresses~norm('239.255.42.1',47001,'eth0','',1001,'replication.group')
r=.RegisteredSocketAddressProvider~new~register('replication.group',a)
s=.SocketSelector~new(r)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new))
c=s~sender('replication.group')
c~send('semantic bytes from caller')
c~close
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
