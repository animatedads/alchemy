b=.SftpMemoryBackend~new
e=.SftpEndpoint~new(b)
s=.SftpChannelService~new(e)
f1=.SftpTest~init(3)
f2=.SftpTest~request(.SftpTypes~REALPATH,1,.SftpCodec~string('/'))
cut=3
r=s~receive(left(f1,cut))
call assert r~items=0,'partial frame withheld'
r=s~receive(substr(f1,cut+1)||f2)
call assert r~items=2,'coalesced frames separated'
call assert .SftpTest~replyType(r[1])=.SftpTypes~VERSION,'first reply version'
call assert .SftpTest~replyType(r[2])=.SftpTypes~NAME,'second reply name'
call assert s~pendingBytes=0,'no residue'
say 'PASS test_framer'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
