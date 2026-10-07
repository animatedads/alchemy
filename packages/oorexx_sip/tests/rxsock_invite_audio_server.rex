s=.SipServer~new('127.0.0.1',5099,'test-realm')
say 'READY' s~port
e=s~poll(5)
say 'TYPE' e[1]
say 'CALLID' e[2]
say 'PEER' e[3] e[4]
say 'RTP_REMOTE' e[5]
say 'RTP_LOCAL' e[6]
say 'PAYLOAD' e[7]
if e[1]='invite' then do
  callId=e[2]
  s~call(callId)~rtpReceiver~start
  s~call(callId)~audioIn~start
  audio=s~receiveAudio(callId,3000,1600)
  say 'AUDIO_BYTES' audio~length
end
s~close
::requires 'sip.cls'
