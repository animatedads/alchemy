parse arg group port iface source node timeoutMs
if group='' then group='239.255.42.61'
if port='' then port=47061
if iface='' then iface='lo'
if source='-' then source=''
if node='' then node=2
if timeoutMs='' then timeoutMs=10000
mdata=.directory~new
mdata['loopback']=.true
addr=.SocketAddresses~norm(group,port,iface,source,node,'norm.live.descriptor',mdata)
p=.RegisteredSocketAddressProvider~new~register('norm.live.descriptor',addr)
s=.SocketSelector~new(p)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new(.NormNativeApi~new)))
m=s~join('norm.live.descriptor')
if m=.nil then call fail 'join'
l=s~listenerOn(m)
if l=.nil then call fail 'listenerOn'
say 'DESCRIPTOR|'||l~descriptor
if l~descriptor<0 then call fail 'descriptor'
a=.nil
do while a=.nil
  if \l~waitReady(timeoutMs) then call fail 'readiness timeout'
  a=l~tryAccept
end
payload=a~recv(2000000)
say 'RECEIVED_LENGTH|'||length(payload)
say 'RECEIVED_PREFIX|'||left(payload,24)
expected=copies('NORM-REPAIR-QUALIFICATION-',20000)
if payload<>expected then call fail 'payload mismatch'
l~close
if \m~joined then call fail 'listener closed membership'
if \m~leave then call fail 'leave'
say 'READY_RECEIVE_PASS'
exit 0
fail: procedure
 parse arg why
 say 'FAIL|'||why
 exit 1
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
::requires 'NormNativeBinding.cls'
