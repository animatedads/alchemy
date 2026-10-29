/* XTP session wire source-review smoke, not production authentication. */
mock=.MockXtpSession~new
factory=.MockFactory~new(mock)
codec=.MockCodec~new
wire=.QueueXtpSessionWire~new(factory,codec,.MockResult,'ED209F','queue.channel.f',1000,1000,8)
answer=wire~deliver('MANAGER-F','RX','ENV','principal')
if \answer~ok then exit 1
artifact=answer~value
if artifact~payload<>'RESULT' then exit 2
if factory~mode<>'encrypt' then exit 3
mock~mode='none'
answer=wire~deliver('MANAGER-F','RX','ENV','principal')
if answer~ok | answer~code<>'XTP_SESSION_IDENTITY_MISMATCH' then exit 4
mock~mode='encrypt';mock~reply='123456789'
answer=wire~deliver('MANAGER-F','RX','ENV','principal')
if answer~ok | answer~code<>'XTP_RESPONSE_TOO_LARGE' then exit 5
mock~reply='RESULT';mock~flag='TIMEOUT'
answer=wire~deliver('MANAGER-F','RX','ENV','principal')
if answer~ok | answer~code<>'XTP_RESPONSE_UNCERTAIN' then exit 6
say 'PASS queue XTP session wire source smoke (5 assertions)'
exit 0
::class MockResult public
::attribute ok get
::attribute code get
::attribute value get
::method init
  expose ok code value
  use strict arg ok,code,value=.nil
::method success class
  use arg value=.nil,detail=''
  return self~new(.true,'OK',value)
::method failure class
  use arg code,detail=''
  return self~new(.false,code)
::class MockCodec public
::method encodeDelivery
  use strict arg manager,channel,envelope,principal
  return 'DELIVER-ENV'
::class MockFactory public
::attribute mode get
::method init
  expose obj mode
  use strict arg obj
::method open
  expose obj mode
  use strict arg peer,service,timeout,protection
  mode=protection
  return obj
::class MockXtpSession public
::attribute mode
::attribute reply
::attribute flag
::method init
  expose mode reply flag
  mode='encrypt';reply='RESULT';flag='EOM'
::method info
  expose mode
  d=.directory~new
  d['PROTECTION']=mode
  d['SERVICE']='queue.channel.f'
  d['PEER']='ED209F'
  d['KEYID']='00000000000c0de1'
  return d
::method write
  use strict arg bytes,eom,timeout
  return bytes~length
::method read
  expose reply
  use strict arg maxBytes,timeout
  return reply
::method lastFlag
  expose flag
  return flag
::method abort
  return 0
::method close
  use strict arg timeout
  return .true
::requires 'QueueXtpSessionWire.cls'
