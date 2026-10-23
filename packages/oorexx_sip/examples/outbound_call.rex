/* Minimal outbound SIP call.  Signalling, media and application control remain
   independently managed objects. */
parse arg target localUri contactUri
if target="" then target="sip:1002@127.0.0.1:5060"
if localUri="" then localUri="sip:1001@127.0.0.1"
if contactUri="" then contactUri="sip:1001@127.0.0.1:5072"

client=.SipClient~new("127.0.0.1",5072)
call=client~invite(target,localUri,contactUri,0,5)
if call==.nil then do
  say "INVITE failed"
  client~close
  exit 2
end

say "CALL-ID" call~callId
say "DIALOG" call~dialog~objectId call~dialog~state
say "CONTROL" call~control~objectId call~control~state
say "AUDIO-IN" call~audioIn~objectId call~audioIn~state
say "AUDIO-OUT" call~audioOut~objectId call~audioOut~state
say "RTP-RX" call~rtpReceiver~objectId call~rtpReceiver~state
say "RTP-TX" call~rtpSender~objectId call~rtpSender~state

/* Application decides these lifecycles explicitly. */
call~rtpReceiver~start
call~rtpSender~start
call~audioIn~start
call~audioOut~start
call~control~start

say "Press Enter to send BYE"
pull .
status=call~dialog~bye
say "BYE STATUS" status
call~releaseResources
client~close

::requires "sip.cls"