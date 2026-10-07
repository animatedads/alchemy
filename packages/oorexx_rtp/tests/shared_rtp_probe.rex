addresses=.RegisteredSocketAddressProvider~new
selector=.SocketSelector~new(addresses)
selector~registerBinding(.SocketTransportKind~UDP,.RxSockUdpBinding~new)
rxEndpoint=.RtpEndpoint~new(selector,"127.0.0.1",0)
txEndpoint=.RtpEndpoint~new(selector,"127.0.0.1",0)
receiver=.RtpReceiver~new(rxEndpoint,0,"probe")
sender=.RtpSender~new(txEndpoint,"127.0.0.1",rxEndpoint~localPort,0,"probe")
receiver~start
sender~start
pcm=copies(d2c(0),320)
frame=.RtpAudioFrame~new(pcm,8000,1,"S16LE",0,160)
sendResult=sender~sendFrame(frame)
if sendResult=.nil then do; say "FAIL send"; exit 1; end
received=receiver~receiveFrame(2000,1600)
if received=.nil then do; say "FAIL receive"; exit 1; end
say "CARRIER" rxEndpoint~carrierAddress~scheme rxEndpoint~carrierAddress~transport
say "PORTS" txEndpoint~localPort rxEndpoint~localPort
say "FRAME" received~bytes received~sampleCount received~payloadType received~sequence received~timestamp
if received~bytes<>320 then exit 1
if received~sampleCount<>160 then exit 1
if received~payloadType<>0 then exit 1
say "PASS RTP over SocketProvider UDP"
sender~close
receiver~close
txEndpoint~close
rxEndpoint~close
::requires "rtp.cls"
::requires "RxSockUdpBinding.cls"
