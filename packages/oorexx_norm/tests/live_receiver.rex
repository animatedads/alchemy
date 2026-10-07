parse arg group port iface node
if group='' then group='239.255.42.1'
if port='' then port=47001
if iface='' then iface='lo'
if node='' then node=2
addr=.SocketAddresses~norm(group,port,iface,'',node,'norm.live')
p=.RegisteredSocketAddressProvider~new~register('norm.live',addr)
s=.SocketSelector~new(p)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new))
l=s~listener('norm.live')
a=l~accept
payload=a~recv(1048576)
say 'RECEIVED|'||payload
l~close
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
