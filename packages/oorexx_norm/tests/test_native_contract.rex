say 'NORM_VERSION|'||normNativeVersion()
m=.directory~new
m['ttl']=1
m['loopback']=.true
a=.SocketAddresses~norm('239.255.42.1',47001,'lo','',42,'norm.native',m)
r=.RegisteredSocketAddressProvider~new~register('norm.native',a)
s=.SocketSelector~new(r)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new))
c=s~sender('norm.native')
if c=.nil then call fail 'no sender'
if c~descriptor<>99 then call fail 'descriptor'
if c~send('abc')<>3 then call fail 'send'
if c~close<>0 then call fail 'close'
say 'PASS NORM native provider contract'
exit 0
fail: procedure
  parse arg why
  say 'FAIL' why
  exit 1
::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
