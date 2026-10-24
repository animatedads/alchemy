parse arg group port iface source node lossPercent paritySymbols holdSeconds
if group='' then group='239.255.42.61'
if port='' then port=47061
if iface='' then iface='lo'
if source='-' then source=''
if node='' then node=1
if lossPercent='' then lossPercent=0
if paritySymbols='' then paritySymbols=16
if holdSeconds='' then holdSeconds=4
payload=copies('NORM-REPAIR-QUALIFICATION-',20000)
m=.directory~new
m['loopback']=.true
m['txRate']=8000000
m['segmentSize']=1200
m['dataSymbols']=64
m['paritySymbols']=paritySymbols
m['qualificationTxLossPercent']=lossPercent
addr=.SocketAddresses~norm(group,port,iface,source,node,'norm.live.sender',m)
p=.RegisteredSocketAddressProvider~new~register('norm.live.sender',addr)
s=.SocketSelector~new(p)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new(.NormNativeApi~new)))
c=s~sender('norm.live.sender')
if c=.nil then call fail 'sender'
n=c~send(payload)
say 'SENT_LENGTH|'||n
say 'SENDER_DESCRIPTOR|'||c~descriptor
if n<>length(payload) then call fail 'send length'
address system 'sleep '||holdSeconds
c~close
say 'SENDER_PASS'
exit 0
fail: procedure
 parse arg why
 say 'FAIL|'||why
 exit 1
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
::requires 'NormNativeBinding.cls'
