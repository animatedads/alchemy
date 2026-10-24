parse arg group port iface node
if group='' then group='239.255.42.1'
if port='' then port=47001
if iface='' then iface='lo'
if node='' then node=2
addr=.SocketAddresses~norm(group,port,iface,'',node,'norm.live')
p=.RegisteredSocketAddressProvider~new~register('norm.live',addr)
s=.SocketSelector~new(p)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new(.NormNativeApi~new)))
m=s~join('norm.live')
if m=.nil then do; say 'FAIL|JOIN'; exit 12; end
say 'JOINED|'||m~address~canonical||'|descriptor='||m~descriptor
l=s~listenerOn(m)
if l=.nil then do; say 'FAIL|LISTENER_ON'; exit 13; end
a=l~accept
payload=a~recv(1048576)
say 'RECEIVED|'||payload
l~close
if \m~joined then do; say 'FAIL|LISTENER_LEFT_MEMBERSHIP'; exit 14; end
say 'LISTENER_CLOSED|MEMBERSHIP_STILL_JOINED'
if \m~leave then do; say 'FAIL|LEAVE'; exit 15; end
say 'LEFT|'||m~state
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
::requires 'NormNativeBinding.cls'
