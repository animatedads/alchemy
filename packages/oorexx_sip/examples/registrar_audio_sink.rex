/* RxSock SIP registrar/UAS with native RTP/G.711 media receive. */
server = .SipServer~new("0.0.0.0", 5060, "oorexx-sip")
say "ooRexx SIP listening UDP" server~port "via RxSock"
say "Press Ctrl-C to stop."
do forever
  event = server~poll(1)
  select
    when event[1] = "timeout" then nop
    when event[1] = "registered" then say "REGISTER" event[2] "from" event[5] || ":" || event[6]
    when event[1] = "register-challenge" then say "REGISTER challenge" event[2]
    when event[1] = "invite" then do
      say "INVITE" event[2] "RTP local" event[6] "payload" event[7]
      callObject = server~call(event[2])
      callObject~rtpReceiver~start
      callObject~audioIn~start
      pcm = server~receiveAudio(event[2], 1000, 1600)
      if pcm~length > 0 then say "RTP audio PCM bytes:" pcm~length
    end
    otherwise say "SIP event:" event[1]
  end
end
::requires "sip.cls"
