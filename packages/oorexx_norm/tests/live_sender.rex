parse arg group port iface node payload
if group='' then group='239.255.42.1'
if port='' then port=47001
if iface='' then iface='lo'
if node='' then node=1
if payload='' then payload='NORM-OO REXX-LIVE-QUALIFICATION'
addr=.SocketAddresses~norm(group,port,iface,'',node,'norm.live')
p=.RegisteredSocketAddressProvider~new~register('norm.live',addr)
s=.SocketSelector~new(p)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new))
c=s~sender('norm.live')
say 'SENT|'||c~send(payload)||'|'||payload
call syssleep 1
c~close
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
::requires 'rxunixsys'
