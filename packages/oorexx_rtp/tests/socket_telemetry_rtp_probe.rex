identity=.InstrumentationCodec~identity("alchemy","rtp-socket","rtp-probe","local","","SOCKET")
observer=.SocketInstrumentationObserver~new(identity)
addresses=.RegisteredSocketAddressProvider~new
selector=.SocketSelector~new(addresses)
selector~registerBinding(.SocketTransportKind~UDP,.TelemetrySocketBinding~new(.RxSockUdpBinding~new,observer))
rxEndpoint=.RtpEndpoint~new(selector,"127.0.0.1",0)
txEndpoint=.RtpEndpoint~new(selector,"127.0.0.1",0)
receiver=.RtpReceiver~new(rxEndpoint,0,"telemetry-probe")
sender=.RtpSender~new(txEndpoint,"127.0.0.1",rxEndpoint~localPort,0,"telemetry-probe")
receiver~start
sender~start
pcm=copies(d2c(0),320)
frame=.RtpAudioFrame~new(pcm,8000,1,"S16LE",0,160)
sendOutcome=sender~sendFrame(frame)
received=receiver~receiveFrame(2000,1600)
if sendOutcome=.nil | received=.nil then do; say "FAIL RTP telemetry flow"; exit 1; end
sender~close
receiver~close
txEndpoint~close
rxEndpoint~close
snapshot=observer~snapshot
samples=snapshot["samples"]
bytesIn=metricValue(samples,"io.bytes.in.total")
bytesOut=metricValue(samples,"io.bytes.out.total")
listeners=metricValue(samples,"socket.listeners.active")
if bytesIn<172 then do; say "FAIL bytes in" bytesIn; exit 1; end
if bytesOut<172 then do; say "FAIL bytes out" bytesOut; exit 1; end
if listeners<>0 then do; say "FAIL listener gauge" listeners; exit 1; end
say "SOCKET_RTP_BYTES" bytesIn bytesOut
say "PASS RTP over observed SocketProvider UDP"
exit 0

metricValue: procedure
  use strict arg samples,name
  do sample over samples
    if sample["name"]=name then return sample["value"]
  end
  return 0

::requires "rtp.cls"
::requires "SocketTelemetryInstrumentation.cls"
::requires "RxSockUdpBinding.cls"